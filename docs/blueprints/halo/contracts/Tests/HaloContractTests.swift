import Testing
import Foundation
import HaloModel

@Suite struct HaloContractTests {
    func keyed() -> HaloComposition {
        var solid = HaloLayer(
            id: "s", name: "Solid 1", kind: .solid, inFrame: 0, outFrame: 60,
            color: HaloLayerColor(red: 1, green: 0, blue: 0), rect: HaloLayerRect(x: 0, y: 0, width: 100, height: 100))
        solid.tracks["x"] = [HaloKeyframe(frame: 0, value: 50), HaloKeyframe(frame: 30, value: 150)]
        let null = HaloLayer(id: "n", name: "Null 1", kind: .null, inFrame: 0, outFrame: 60, color: HaloLayerColor(red: 0, green: 0, blue: 0))
        return HaloComposition(id: "c", name: "Intro", width: 400, height: 200, framesPerSecond: 24, durationFrames: 60, layers: [null, solid])
    }

    @Test func fakeDrawListSkipsNullsAndInterpolates() {
        let list = FakeFrameDrawing().drawList(keyed(), at: 15)
        #expect(list.items.map(\.layerID) == ["s"])
        #expect(FakeLayerPlacing().value(.x, of: "s", in: keyed(), at: 15) == 100)
    }

    @Test func fakeEaseInBendsTheCurve() throws {
        var comp = keyed()
        try FakeKeyEasing().setEasing(.easeIn, on: [HaloKeyRef(layerID: "s", property: .x, frame: 0)], in: &comp)
        #expect((FakeLayerPlacing().value(.x, of: "s", in: comp, at: 15) ?? 0) < 100)
        #expect(HaloEasingPreset(FakeKeyEasing().easing(of: HaloKeyRef(layerID: "s", property: .x, frame: 0), in: comp) ?? .linear) == .easeIn)
    }

    @Test func fakeDragKeysAnimatedPosition() throws {
        var comp = keyed()
        #expect(FakeViewerDragging().hit(comp, at: 0, point: HaloPoint(x: 50, y: 50)) == "s")
        try FakeViewerDragging().commitMove("s", by: HaloPoint(x: 10, y: 0), at: 15, in: &comp)
        #expect(comp.layers[1].tracks["x"]?.map(\.frame) == [0, 15, 30])
    }

    @Test func fakeParentingFollowsAndRefusesCycles() throws {
        var comp = keyed()
        let keying = FakePropertyKeying(), placing = FakeLayerPlacing()
        let before = placing.worldMatrix(of: "s", in: comp, at: 0)?.apply(HaloPoint(x: 50, y: 50))
        try keying.setParent("n", of: "s", at: 0, in: &comp)
        #expect(placing.worldMatrix(of: "s", in: comp, at: 0)?.apply(HaloPoint(x: 50, y: 50)) == before)
        #expect(placing.parentCandidates(for: "n", in: comp).isEmpty)
        #expect(throws: HaloEditError.parentCycle("Null 1")) { try keying.setParent("s", of: "n", at: 0, in: &comp) }
        try keying.setValue(300, for: .x, of: "n", at: 0, in: &comp)
        #expect(placing.worldMatrix(of: "s", in: comp, at: 0)?.apply(HaloPoint(x: 50, y: 50)).x == (before?.x ?? 0) + 100)
    }

    @Test func fakeOpacityHasOneStaticHome() throws {
        var comp = keyed()
        let keying = FakePropertyKeying()
        try keying.setValue(0.5, for: .opacity, of: "s", at: 10, in: &comp)
        #expect(comp.layers[1].opacity == 0.5 && comp.layers[1].tracks["opacity"] == nil)
        try keying.toggleAnimation(.opacity, of: "s", at: 10, in: &comp)
        #expect(comp.layers[1].tracks["opacity"]?.map(\.frame) == [10, 59])
        try keying.toggleAnimation(.opacity, of: "s", at: 10, in: &comp)
        #expect(comp.layers[1].opacity == 0.5 && comp.layers[1].tracks["opacity"] == nil)
    }

    @Test func fakeHistoryCoalescesEndsAndClearsRedo() {
        let history = FakeProjectHistory()
        var h = HaloHistory()
        let a = HaloDocumentState(), b = HaloDocumentState(nextCompositionNumber: 2)
        history.record("Change Rotation", before: a, coalesceKey: "rot", in: &h)
        history.record("Change Rotation", before: b, coalesceKey: "rot", in: &h)
        #expect(h.undo.count == 1)
        #expect(h.undoTitle == "Undo Change Rotation")
        history.endCoalescing(in: &h)
        history.record("Change Rotation", before: b, coalesceKey: "rot", in: &h)
        #expect(h.undo.count == 2)
        #expect(history.undo(b, in: &h) == b)
        history.record("Change Rotation", before: a, coalesceKey: "rot", in: &h)
        #expect(h.redo.isEmpty)
    }

    @Test func fakeFilesRoundTripAndRefuse() throws {
        let state = HaloDocumentState(compositions: [keyed()], selectedCompositionID: "c", nextCompositionNumber: 2)
        let files = FakeProjectFiles()
        #expect(try files.decode(files.encode(state)) == state)
        #expect(throws: HaloFileError.notAHaloFile) { try files.decode(Data("not json".utf8)) }
        #expect(throws: HaloFileError.newerVersion(2)) { try files.decode(Data(#"{"format":"halo","version":2}"#.utf8)) }
        #expect(throws: HaloFileError.damaged("it has no project")) { try files.decode(Data(#"{"format":"halo","version":1}"#.utf8)) }
    }

    @Test func fakeRenderRunsEveryFrameAtThePlanSize() throws {
        struct Count: RenderSink {
            var names: [String] = []
            var widths: Set<Int> = []
            mutating func begin(_ plan: HaloRenderPlan) throws {}
            mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws {
                names.append(fileName); widths.insert(frame.pixels.width)
            }
            mutating func finish(cancelled: Bool) throws {}
        }
        let r = FakeCompositionRendering()
        let plan = try r.plan(keyed(), settings: HaloRenderSettings(format: .pngSequence, halfSize: true))
        var sink = Count()
        #expect(r.run(plan, of: keyed(), text: nil, into: &sink, isCancelled: { false }) == .finished(frames: 60))
        #expect(sink.names.first == "Intro_0001.png" && sink.names.last == "Intro_0060.png")
        #expect(sink.widths == [200])
    }

    @Test func liveStubsSayWhyAndClockMatchesFlareCoreEdges() {
        #expect(HaloServices.live.drawing.unavailableHelp != nil)
        #expect(HaloServices.fake.drawing.unavailableHelp == nil)
        #expect(FakePlaybackClock().tick(startFrame: 50, elapsed: 1, framesPerSecond: 24, durationFrames: 60, loops: true).frame == 14)
        #expect(FakePlaybackClock().tick(startFrame: 0, elapsed: 0.7, framesPerSecond: 30, durationFrames: 60, loops: false).frame == 21)
        #expect(HaloProperty.rotation.parse(" 45° ") == 45 && HaloProperty.opacity.parse("50%") == 0.5)
        #expect(HaloProperty.rotation.parse("abc") == nil)
    }
}
