// ServicesAdversarialTests.swift: NotBuilt behind every FlareServices member, every write and every read
// (docs/blueprints/flare.md, 6.3). A write throws that member's own reason and leaves the engine untouched;
// a read is empty whatever it is handed.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import FlareModel
import Synchronization
import Testing

private let scene = FlareScene(id: "scene-1", name: "Scene 1")
private let doc = Document(scenes: [scene], swatches: [Swatch(name: "Red", color: FlareColor(r: 1, g: 0, b: 0))])
private let owner = LayerOwner.scene("scene-1")
private let address = StageAddress(owner: owner, layerID: "ball", item: .shape(0))
private let state = MachineState(id: "idle", name: "Idle", sceneID: "scene-1", startFrame: 0, endFrame: 10)
private let transition = FlareTransition(from: "idle", to: "hover", trigger: "tap")
private let input = MachineInput(name: "hover", defaultValue: .bool(false))
private let draft = ShapeDraft(tool: .rectangle, shape: FlareShape(points: [Point(x: 0, y: 0), Point(x: 1, y: 1)]))

/// The reason each member of a services value is expected to carry.
private struct Reasons {
    var scenes, stage, hits, shapes, properties, keyframes, easing, onion, library, machines, preview, export, assist: String
}

/// Distinct per member, so a write that reaches the wrong member shows up.
private let reasons = Reasons(
    scenes: "scenes", stage: "stage", hits: "hits", shapes: "shapes", properties: "properties",
    keyframes: "keyframes", easing: "easing", onion: "onion", library: "library", machines: "machines",
    preview: "preview", export: "export", assist: "assist")

/// Every member NotBuilt with its own reason. Built here, not taken from `.fake` or `.live`, because the
/// LM-0 and IN tasks swap those members for real fakes and live conformances one at a time.
private func notBuilt(_ r: Reasons = reasons) -> FlareServices {
    FlareServices(
        scenes: NotBuilt(reason: r.scenes), stage: NotBuilt(reason: r.stage), hits: NotBuilt(reason: r.hits),
        shapes: NotBuilt(reason: r.shapes), properties: NotBuilt(reason: r.properties),
        keyframes: NotBuilt(reason: r.keyframes), easing: NotBuilt(reason: r.easing), onion: NotBuilt(reason: r.onion),
        library: NotBuilt(reason: r.library), machines: NotBuilt(reason: r.machines), preview: NotBuilt(reason: r.preview),
        export: NotBuilt(reason: r.export), assist: NotBuilt(reason: r.assist), isPreview: true)
}

private struct Rasterizer: FrameRasterizing {
    func png(_: StageDrawList, scale _: Double, transparent _: Bool) throws -> Data { Data([0x89]) }
}

/// Runs `write` on a fresh engine and checks it throws exactly `reason` and changes nothing.
private func expectRefused(_ reason: String, _ write: (inout CommandEngine) throws -> Void,
                           sourceLocation: SourceLocation = #_sourceLocation) {
    var engine = CommandEngine(document: doc)
    #expect(throws: NotBuilt(reason: reason), sourceLocation: sourceLocation) { try write(&engine) }
    #expect(engine.document == doc && !engine.canUndo && !engine.canRedo, sourceLocation: sourceLocation)
}

private func expectEveryWriteRefused(_ s: FlareServices, _ r: Reasons) {
    expectRefused(r.scenes) { _ = try s.scenes.addScene(.web, in: &$0) }
    expectRefused(r.scenes) { try s.scenes.renameScene("scene-1", to: "Intro", in: &$0) }
    expectRefused(r.scenes) { try s.scenes.removeScene("scene-1", in: &$0) }
    expectRefused(r.scenes) { try s.scenes.reorderScene("scene-1", to: 0, in: &$0) }
    expectRefused(r.scenes) { try s.scenes.setCanvas("scene-1", width: 10, height: 10, background: FlareColor(r: 0, g: 0, b: 0), in: &$0) }
    expectRefused(r.scenes) { try s.scenes.setTiming("scene-1", fps: 30, durationFrames: 60, in: &$0) }
    expectRefused(r.scenes) { _ = try s.scenes.addGuide(.horizontal, at: 5, sceneID: "scene-1", in: &$0) }
    expectRefused(r.scenes) { try s.scenes.moveGuide(at: 0, to: 9, sceneID: "scene-1", coalesceKey: "g", in: &$0) }
    expectRefused(r.scenes) { try s.scenes.removeGuide(at: 0, sceneID: "scene-1", in: &$0) }

    expectRefused(r.shapes) { _ = try s.shapes.commit(draft, owner: .scene("scene-1"), aboveLayerID: nil, in: &$0) }
    expectRefused(r.shapes) {
        try s.shapes.commitBox(.move(dx: 1, dy: 1), layers: ["ball"], sceneID: "scene-1", frame: 0,
                               box: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1), autoKey: true, in: &$0)
    }
    expectRefused(r.shapes) { try s.shapes.setPath(FlarePath(), of: address, in: &$0) }
    expectRefused(r.shapes) { try s.shapes.translate([address], dx: 1, dy: 1, in: &$0) }
    expectRefused(r.shapes) { try s.shapes.delete([address], in: &$0) }
    expectRefused(r.shapes) { _ = try s.shapes.duplicate(layers: ["ball"], owner: owner, in: &$0) }
    expectRefused(r.shapes) { _ in _ = try s.shapes.copy(layers: ["ball"], owner: owner, from: doc) }
    expectRefused(r.shapes) { _ = try s.shapes.paste(Data(), owner: owner, aboveLayerID: nil, offset: 10, in: &$0) }

    expectRefused(r.properties) {
        try s.properties.setValue(1, of: "x", owner: owner, layerIDs: ["ball"], frame: 0, autoKey: true, coalesceKey: nil, in: &$0)
    }
    expectRefused(r.properties) { try s.properties.toggleAnimated("x", owner: owner, layerID: "ball", frame: 0, lastFrame: 47, in: &$0) }
    expectRefused(r.properties) { try s.properties.toggleKey("x", owner: owner, layerID: "ball", frame: 0, in: &$0) }
    expectRefused(r.properties) { try s.properties.setFill(.solid(FlareColor(r: 0, g: 0, b: 1)), of: [address], in: &$0) }
    expectRefused(r.properties) { try s.properties.setStroke(nil, of: [address], in: &$0) }

    let key = KeyRef(layerID: "ball", property: "x", frame: 0)
    expectRefused(r.keyframes) { try s.keyframes.moveKeys([key], by: 2, owner: owner, coalesceKey: "k", in: &$0) }
    expectRefused(r.keyframes) { try s.keyframes.removeKeys([key], owner: owner, in: &$0) }
    expectRefused(r.keyframes) { try s.keyframes.insertFrames(2, at: 0, layerIDs: ["ball"], owner: owner, in: &$0) }
    expectRefused(r.keyframes) { try s.keyframes.removeFrames(2, at: 0, layerIDs: ["ball"], owner: owner, in: &$0) }
    expectRefused(r.keyframes) { try s.keyframes.setLabel("start", at: 0, sceneID: "scene-1", in: &$0) }
    expectRefused(r.easing) { try s.easing.setEasing(.hold, at: key, owner: owner, coalesceKey: nil, in: &$0) }

    expectRefused(r.library) { _ = try s.library.convertToSymbol(["ball"], sceneID: "scene-1", name: "Ball", in: &$0) }
    expectRefused(r.library) { _ = try s.library.placeInstance(of: "star", at: Point(x: 0, y: 0), owner: owner, layerID: "ball", in: &$0) }
    expectRefused(r.library) { try s.library.setInstanceTransform(Transform(x: 4), at: address, coalesceKey: "t", in: &$0) }
    expectRefused(r.library) { try s.library.setInstancePlayback(.playOnce, firstFrame: 3, at: address, in: &$0) }
    expectRefused(r.library) { try s.library.renameSymbol("star", to: "Sun", in: &$0) }
    expectRefused(r.library) { try s.library.addSwatch(Swatch(name: "Blue", color: FlareColor(r: 0, g: 0, b: 1)), in: &$0) }
    expectRefused(r.library) { try s.library.removeSwatch("Red", in: &$0) }

    expectRefused(r.machines) { _ = try s.machines.addMachine(named: "Button", firstState: state, in: &$0) }
    expectRefused(r.machines) { try s.machines.renameMachine("m", to: "N", in: &$0) }
    expectRefused(r.machines) { try s.machines.removeMachine("m", in: &$0) }
    expectRefused(r.machines) { try s.machines.addState(state, to: "m", in: &$0) }
    expectRefused(r.machines) { try s.machines.updateState(state, in: "m", in: &$0) }
    expectRefused(r.machines) { try s.machines.removeState("idle", from: "m", in: &$0) }
    expectRefused(r.machines) { try s.machines.addTransition(transition, to: "m", in: &$0) }
    expectRefused(r.machines) { try s.machines.updateTransition(at: 0, to: transition, in: "m", in: &$0) }
    expectRefused(r.machines) { try s.machines.removeTransition(at: 0, from: "m", in: &$0) }
    expectRefused(r.machines) { try s.machines.addInput(input, to: "m", in: &$0) }
    expectRefused(r.machines) { try s.machines.updateInput(input, in: "m", in: &$0) }
    expectRefused(r.machines) { try s.machines.removeInput(named: "hover", from: "m", in: &$0) }
    expectRefused(r.machines) { try s.machines.setInitialState("idle", of: "m", in: &$0) }
    expectRefused(r.preview) { _ in _ = try s.preview.start(doc, machineID: "m") }
}

@Test func everyNotBuiltWriteThrowsItsOwnMembersReason() {
    expectEveryWriteRefused(notBuilt(), reasons)
}

@Test func notBuiltAssistReportsItsReasonAndThrowsIt() async {
    let services = notBuilt()
    #expect(services.assist.unavailableHelp == "assist")
    await #expect(throws: NotBuilt(reason: "assist")) {
        try await services.assist.propose("", document: doc, selection: [address], frame: -1)
    }
    #expect(FakeAssistMode.allCases.allSatisfy { FlareServices.fake(assistMode: $0).isPreview })
}

@Test func exportThrowsItsReasonWithoutReportingProgress() async {
    let services = notBuilt()
    let reason = "export"
    let calls = Mutex(0)
    for format in ExportFormat.allCases {
        let options = ExportOptions(format: format, sceneID: "scene-1", frames: 0...12, step: 2, scale: 2, transparentBackground: true)
        await #expect(throws: NotBuilt(reason: reason)) {
            try await services.export.export(doc, options: options, rasterizer: Rasterizer()) { _ in calls.withLock { $0 += 1 } }
        }
    }
    #expect(calls.withLock { $0 } == 0)
}

@Test func everyNotBuiltReadIsEmptyEvenForUnknownIDs() {
    let s = notBuilt()
    let other = LayerOwner.symbol("missing")
    let fresh = s.scenes.newDocument(.hd1080)
    #expect(fresh.scenes.isEmpty && fresh.symbols.isEmpty && fresh.stateMachines.isEmpty && fresh.swatches.isEmpty)

    let list = s.stage.drawList(doc, sceneID: "nope", frame: -5, editing: "missing")
    #expect(list.items.isEmpty && list.hiddenTextCount == 0)
    let box = Rect(minX: -1e9, minY: -1e9, maxX: 1e9, maxY: 1e9)
    #expect(s.hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 0, y: 0), tolerance: .infinity) == nil)
    #expect(s.hits.marquee(doc, sceneID: "scene-1", frame: 0, rect: box).isEmpty)
    #expect(s.hits.bounds(doc, sceneID: "scene-1", frame: 0, of: [address]) == nil)

    for tool in FlareTool.allCases {
        #expect(s.shapes.unavailableHelp(for: tool) == "shapes")
        #expect(s.shapes.draft(tool, from: Point(x: 0, y: 0), to: Point(x: 50, y: 50), modifiers: [.shift, .option], previous: draft) == nil)
    }
    #expect(s.shapes.boxResult(.rotate(degrees: 45), layers: ["ball"], document: doc, sceneID: "scene-1", frame: 0, box: box).isEmpty)

    #expect(s.properties.properties(doc, owner: owner, layerIDs: ["ball"], frame: 0).isEmpty)
    #expect(s.keyframes.rows(doc, owner: other).isEmpty && s.keyframes.labels(doc, sceneID: "scene-1").isEmpty)
    #expect(s.easing.presets.isEmpty && s.easing.curve(.cubicBezier(x1: 0.4, y1: 0, x2: 0.2, y2: 1), count: 64).isEmpty)
    #expect(s.onion.ghosts(doc, sceneID: "scene-1", layerIDs: ["ball"], frame: 5, settings: OnionSettings(isOn: true, before: 3, after: 3)).isEmpty)
    #expect(s.onion.motionPath(doc, owner: owner, layerID: "ball").isEmpty)

    // A document with a swatch still lists none: NotBuilt reads nothing from the document.
    #expect(s.library.symbols(doc).isEmpty && s.library.swatches(doc).isEmpty)
    #expect(s.machines.machines(doc).isEmpty && s.machines.issues(doc, machineID: "m").isEmpty)
    let options = ExportOptions(format: .lottie, sceneID: "scene-1", frames: 0...0, transparentBackground: true)
    #expect(s.export.warnings(doc, options: options).isEmpty)
}

@Test func notBuiltPreviewHandsBackTheSamePreview() {
    let s = notBuilt()
    let preview = MachinePreview(machineID: "m", stateID: "idle", frame: 3, inputs: ["hover": .bool(false), "speed": .number(.nan)])
    #expect(s.preview.set("hover", to: .bool(true), preview, in: doc).inputs["hover"] == .bool(false))
    #expect(s.preview.fire("", preview, in: Document()).stateID == "idle")
    for frames in [Int.min, -1, 0, 1, Int.max] {
        let next = s.preview.advance(preview, frames: frames, in: doc)
        #expect(next.machineID == "m" && next.stateID == "idle" && next.frame == 3)
    }
}

@Test func servicesCrossTasksAndEachMemberCanBeSwappedAlone() async {
    var services = notBuilt()
    services.library = NotBuilt(reason: "Swapped.")
    #expect(services.isPreview)
    let reasons = await withTaskGroup(of: String?.self) { group in
        for _ in 0..<32 {
            group.addTask { [services] in
                var engine = CommandEngine(document: doc)
                do { try services.library.removeSymbol("star", in: &engine) } catch let error as NotBuilt { return error.reason } catch { return nil }
                return nil
            }
        }
        return await group.reduce(into: [String?]()) { $0.append($1) }
    }
    #expect(reasons.count == 32 && reasons.allSatisfy { $0 == "Swapped." })
    expectRefused("scenes") { try services.scenes.removeScene("scene-1", in: &$0) }
}

@Test func notBuiltIsAValueKeyedByItsReason() {
    #expect(NotBuilt(reason: "") == NotBuilt(reason: ""))
    #expect(NotBuilt(reason: "a") != NotBuilt(reason: "A"))
    #expect(Set([NotBuilt(reason: "x"), NotBuilt(reason: "x"), NotBuilt(reason: "y")]).count == 2)
    let error: any Error = NotBuilt(reason: "Not built yet (LM-0a2).")
    #expect("\(error)" == "Not built yet (LM-0a2).")
    #expect(FakeAssistMode(rawValue: "timeout") == .timeout && FakeAssistMode(rawValue: "OK") == nil)
    #expect(FakeAssistMode.allCases.map(\.rawValue) == ["ok", "fail", "timeout", "empty", "text"])
}
