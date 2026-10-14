import Testing
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

    @Test func fakeHistoryCoalescesAndUndoes() {
        let history = FakeProjectHistory()
        var h = HaloHistory()
        let a = HaloDocumentState(), b = HaloDocumentState(nextCompositionNumber: 2)
        history.record("Change Rotation", before: a, coalesceKey: "rot", in: &h)
        history.record("Change Rotation", before: b, coalesceKey: "rot", in: &h)
        #expect(h.undo.count == 1)
        #expect(h.undoTitle == "Undo Change Rotation")
        #expect(history.undo(b, in: &h) == a)
        #expect(h.redoTitle == "Redo Change Rotation")
    }

    @Test func fakeFilesRoundTrip() throws {
        let state = HaloDocumentState(compositions: [keyed()], selectedCompositionID: "c", nextCompositionNumber: 2)
        let files = FakeProjectFiles()
        #expect(try files.decode(files.encode(state)) == state)
    }

    @Test func fakeRenderRunsEveryFrame() throws {
        struct Count: RenderSink {
            var names: [String] = []
            var finished = false
            mutating func begin(_ plan: HaloRenderPlan) throws {}
            mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws { names.append(fileName) }
            mutating func finish(cancelled: Bool) throws { finished = !cancelled }
        }
        let r = FakeCompositionRendering()
        let plan = try r.plan(keyed(), settings: HaloRenderSettings(format: .pngSequence))
        var sink = Count()
        #expect(r.run(plan, of: keyed(), into: &sink, isCancelled: { false }) == .finished(frames: 60))
        #expect(sink.names.first == "Intro_0001.png" && sink.names.last == "Intro_0060.png")
    }

    @Test func liveStubsSayWhy() {
        #expect(HaloServices.live.drawing.unavailableHelp != nil)
        #expect(HaloServices.fake.drawing.unavailableHelp == nil)
        #expect(FakePlaybackClock().tick(startFrame: 50, elapsed: 1, framesPerSecond: 24, durationFrames: 60, loops: true).frame == 14)
    }
}
