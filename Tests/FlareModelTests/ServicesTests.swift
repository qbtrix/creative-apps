// ServicesTests.swift: `.fake` and `.live` are previews; a NotBuilt write throws its reason, a read is empty.
import FlareCore
import FlareModel
import Testing

private let fixture = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1")])

@Test func fakeAndLiveArePreviewsAndNotBuiltReadsAreEmpty() {
    #expect(FakeAssistMode.allCases.allSatisfy { FlareServices.fake(assistMode: $0).isPreview })
    #expect(FlareServices.live.isPreview && FlareServices.live.assist.unavailableHelp == "Assist needs the suite's model provider.")
    #expect(FlareServices.fake().shapes.unavailableHelp(for: .rectangle) == "Not built yet (LM-0a2b).")
    let services = FlareServices.fake()
    #expect(services.stage.drawList(fixture, sceneID: "scene-1", frame: 0, editing: nil).items.isEmpty)
    #expect(services.keyframes.rows(fixture, owner: .scene("scene-1")).isEmpty && services.easing.presets.isEmpty)
    #expect(services.library.symbols(fixture).isEmpty && services.machines.machines(fixture).isEmpty)
    #expect(services.export.warnings(fixture, options: ExportOptions(format: .svgFrame, sceneID: "scene-1", frames: 0...0)).isEmpty)
    let preview = MachinePreview(machineID: "m", stateID: "idle", frame: 0, inputs: ["on": .bool(true)])
    #expect(services.preview.fire("tap", preview, in: fixture) == preview)
}

@Test func notBuiltWriteThrowsItsReasonAndChangesNothing() async {
    let services = FlareServices.live
    var engine = CommandEngine(document: fixture)
    #expect(throws: NotBuilt(reason: "Not connected yet (IN-4).")) { try services.scenes.renameScene("scene-1", to: "Intro", in: &engine) }
    #expect(throws: NotBuilt(reason: "Not connected yet (IN-5).")) { try services.library.removeSymbol("star", in: &engine) }
    await #expect(throws: NotBuilt(reason: "Assist needs the suite's model provider.")) {
        try await services.assist.propose("pop in", document: fixture, selection: [], frame: 0)
    }
    #expect(engine.document == fixture && !engine.canUndo && NotBuilt(reason: "Why").description == "Why")
}
