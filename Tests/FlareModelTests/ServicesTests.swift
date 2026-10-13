// ServicesTests.swift: `.fake` and `.live` build and are previews; a NotBuilt write throws its reason, a read is empty.
// A member is checked against its own blueprint state (docs/blueprints/flare.md, 7.1): while it is still
// NotBuilt its reason names the task that builds it; once that task swaps in a real fake or live
// conformance, this file needs no edit (#405).
import FlareCore
import FlareModel
import Testing

private let fixture = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1")])

/// Each member's value as `any Sendable`, keyed by name, so a test can ask whether it is still NotBuilt.
private func members(_ s: FlareServices) -> [(String, any Sendable)] {
    [("scenes", s.scenes), ("stage", s.stage), ("hits", s.hits), ("shapes", s.shapes), ("properties", s.properties),
     ("keyframes", s.keyframes), ("easing", s.easing), ("onion", s.onion), ("library", s.library),
     ("machines", s.machines), ("preview", s.preview), ("export", s.export), ("assist", s.assist)]
}

/// The reason a still-NotBuilt `.fake` member carries: the LM-0 task in 7.1 that builds its fake.
private let fakeReasons = [
    "scenes": "Not built yet (LM-0a2).", "stage": "Not built yet (LM-0a2).", "hits": "Not built yet (LM-0a2).",
    "shapes": "Not built yet (LM-0a2b).", "properties": "Not built yet (LM-0b1).",
    "keyframes": "Not built yet (LM-0b2).", "easing": "Not built yet (LM-0b2).", "onion": "Not built yet (LM-0b2).",
    "library": "Not built yet (LM-0c1).", "machines": "Not built yet (LM-0c2).", "preview": "Not built yet (LM-0c2).",
    "export": "Not built yet (LM-0c3).", "assist": "Not built yet (LM-0c4).",
]

/// The reason a still-NotBuilt `.live` member carries: the IN task that connects it.
private let liveReasons = [
    "scenes": "Not connected yet (IN-4).", "stage": "Not connected yet (IN-1).", "hits": "Not connected yet (IN-1).",
    "shapes": "Not connected yet (IN-1).", "properties": "Not connected yet (IN-1).",
    "keyframes": "Not connected yet (IN-2).", "easing": "Not connected yet (IN-2).", "onion": "Not connected yet (IN-3).",
    "library": "Not connected yet (IN-5).", "machines": "Not connected yet (IN-6).", "preview": "Not connected yet (IN-6).",
    "export": "Not connected yet (IN-7).", "assist": "Assist needs the suite's model provider.",
]

@Test func fakeAndLiveBuildAndArePreviews() {
    #expect(FakeAssistMode.allCases.allSatisfy { FlareServices.fake(assistMode: $0).isPreview })
    #expect(FlareServices.live.isPreview)
    #expect(members(.fake()).count == fakeReasons.count && members(.live).count == liveReasons.count)
}

@Test(arguments: [("fake", FlareServices.fake(), fakeReasons), ("live", FlareServices.live, liveReasons)])
func aStillNotBuiltMemberNamesTheTaskThatBuildsIt(_ name: String, _ services: FlareServices, _ reasons: [String: String]) {
    for (member, value) in members(services) {
        guard let notBuilt = value as? NotBuilt else { continue }  // built: its own task's tests cover it
        #expect(notBuilt.reason == reasons[member], "\(name).\(member)")
    }
}

@Test func reasonsMatchTheirBlueprintTasks() {
    // The tables above are the 7.1 owners; a member's builder never changes when another member lands.
    #expect(Set(fakeReasons.keys) == Set(liveReasons.keys))
    #expect(fakeReasons.values.allSatisfy { $0.hasPrefix("Not built yet (LM-0") })
    #expect(liveReasons.filter { $0.key != "assist" }.values.allSatisfy { $0.hasPrefix("Not connected yet (IN-") })
}

@Test func notBuiltReadsAreEmpty() {
    let services = FlareServices(
        scenes: NotBuilt(reason: "r"), stage: NotBuilt(reason: "r"), hits: NotBuilt(reason: "r"), shapes: NotBuilt(reason: "r"),
        properties: NotBuilt(reason: "r"), keyframes: NotBuilt(reason: "r"), easing: NotBuilt(reason: "r"),
        onion: NotBuilt(reason: "r"), library: NotBuilt(reason: "r"), machines: NotBuilt(reason: "r"),
        preview: NotBuilt(reason: "r"), export: NotBuilt(reason: "r"), assist: NotBuilt(reason: "r"), isPreview: true)
    #expect(services.shapes.unavailableHelp(for: .rectangle) == "r" && services.assist.unavailableHelp == "r")
    #expect(services.stage.drawList(fixture, sceneID: "scene-1", frame: 0, editing: nil).items.isEmpty)
    #expect(services.keyframes.rows(fixture, owner: .scene("scene-1")).isEmpty && services.easing.presets.isEmpty)
    #expect(services.library.symbols(fixture).isEmpty && services.machines.machines(fixture).isEmpty)
    #expect(services.export.warnings(fixture, options: ExportOptions(format: .svgFrame, sceneID: "scene-1", frames: 0...0)).isEmpty)
    let preview = MachinePreview(machineID: "m", stateID: "idle", frame: 0, inputs: ["on": .bool(true)])
    #expect(services.preview.fire("tap", preview, in: fixture) == preview)
}

@Test func notBuiltWriteThrowsItsReasonAndChangesNothing() async {
    let scenes: any SceneEditing = NotBuilt(reason: "Not connected yet (IN-4).")
    let library: any LibraryManaging = NotBuilt(reason: "Not connected yet (IN-5).")
    let assist: any AnimationAssisting = NotBuilt(reason: "Assist needs the suite's model provider.")
    var engine = CommandEngine(document: fixture)
    #expect(throws: NotBuilt(reason: "Not connected yet (IN-4).")) { try scenes.renameScene("scene-1", to: "Intro", in: &engine) }
    #expect(throws: NotBuilt(reason: "Not connected yet (IN-5).")) { try library.removeSymbol("star", in: &engine) }
    await #expect(throws: NotBuilt(reason: "Assist needs the suite's model provider.")) {
        try await assist.propose("pop in", document: fixture, selection: [], frame: 0)
    }
    #expect(engine.document == fixture && !engine.canUndo && NotBuilt(reason: "Why").description == "Why")
}
