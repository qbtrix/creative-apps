// FlareServicesBuiltTests.swift: draw-key-save DK-3. `FlareServices.built` holds the live type for each member whose
// live conformance has merged and `.live`'s `NotBuilt` for the rest; a launch that isn't `-FlareFixture` runs on it,
// so a new document draws through `LiveShapes`. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func reason(_ member: Any) -> String? { (member as? NotBuilt)?.reason }

@Test func builtHoldsTheLiveTypeForEachMergedMember() {
    let built = FlareServices.built
    #expect(type(of: built.stage) == LiveStage.self)
    #expect(type(of: built.hits) == LiveHits.self)
    #expect(type(of: built.shapes) == LiveShapes.self)
    #expect(type(of: built.properties) == LiveProperties.self)
    #expect(type(of: built.keyframes) == LiveKeyframes.self)
    #expect(type(of: built.easing) == LiveEasing.self)
    #expect(type(of: built.scenes) == LiveScenes.self)
}

@Test func builtKeepsLiveReasonsForTheRest() {
    let built = FlareServices.built, live = FlareServices.live
    let pairs: [(Any, Any)] = [(built.onion, live.onion), (built.library, live.library), (built.machines, live.machines),
                               (built.preview, live.preview), (built.export, live.export), (built.assist, live.assist)]
    for (builtMember, liveMember) in pairs {
        #expect(reason(builtMember) != nil && reason(builtMember) == reason(liveMember))
    }
    #expect(built.isPreview == live.isPreview)
    #expect(live.shapes is NotBuilt && live.scenes is NotBuilt)
}

@Test func aPlainLaunchDrawsARectangleThroughLiveShapes() {
    var w = FlareWorkspace(launch: FlareLaunch(arguments: []))
    #expect(type(of: w.services.shapes) == LiveShapes.self)
    w.newDocument()
    w.selectTool(.rectangle)
    w.drag(from: Point(x: 40, y: 40), to: Point(x: 200, y: 160))
    #expect(w.layers.map(\.name) == ["Rectangle 1"])
    #expect(w.undoActionName == "Undo Add Rectangle")
    w.undo()
    #expect(w.layers.isEmpty && !w.canUndo)
}

@Test(arguments: [["-FlareSample", "bounce"], ["-FlareOpenFile", "/tmp/a.flare"]])
func sampleAndOpenFileRunOnBuilt(arguments: [String]) {
    #expect(type(of: FlareWorkspace(launch: FlareLaunch(arguments: arguments)).services.scenes) == LiveScenes.self)
}

@Test func fixtureLaunchStillRunsOnFakes() {
    let w = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
    #expect(w.services.shapes is FakeShapes && w.services.scenes is FakeScenes && w.services.isPreview)
}
