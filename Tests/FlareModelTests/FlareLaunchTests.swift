// FlareLaunchTests.swift: FlareLaunch reads Flare's launch flags, and FlareWorkspace(launch:) picks
// services and opens the fixture they name (draw-key-save, DK-1). Runs on Linux and macOS.
import FlareModel
import Testing

@Test func fixtureFlagLoadsTheFixtureOnFakes() {
    let launch = FlareLaunch(arguments: ["Flare", "-FlareFixture", "bounce"])
    #expect(launch.source == .fixture("bounce"))
    #expect(launch.usesFakes)
    let workspace = FlareWorkspace(launch: launch)
    #expect(workspace.services.scenes is FakeScenes)
    #expect(workspace.document != nil && workspace.document == FlareFixtures.named("bounce"))
    #expect(workspace.selectedSceneID == FlareFixtures.named("bounce")?.scenes.first?.id)
}

@Test func sampleFlagLoadsTheFixtureOnNonFakeServices() {
    let launch = FlareLaunch(arguments: ["-FlareSample", "bounce"])
    #expect(launch.source == .sample("bounce"))
    #expect(!launch.usesFakes)
    let workspace = FlareWorkspace(launch: launch)
    #expect(!(workspace.services.scenes is FakeScenes))
    #expect(workspace.document != nil && workspace.document == FlareFixtures.named("bounce"))
}

@Test func openFileAndSaveFolderAreBothRead() {
    let launch = FlareLaunch(arguments: ["-FlareOpenFile", "/tmp/a.flare", "-FlareSaveTo", "/tmp/out", "-FlareExportTo", "/tmp/exp"])
    #expect(launch.source == .file("/tmp/a.flare"))
    #expect(launch.saveFolder == "/tmp/out")
    #expect(launch.exportFolder == "/tmp/exp")
    #expect(!launch.usesFakes)
    let workspace = FlareWorkspace(launch: launch)
    #expect(workspace.document == nil)
    #expect(!(workspace.services.scenes is FakeScenes))
}

@Test func noFlagsGiveNoSourceAndNoDocument() {
    let launch = FlareLaunch(arguments: [])
    #expect(launch == FlareLaunch(arguments: ["Flare"]))
    #expect(launch.source == .none && launch.saveFolder == nil && launch.exportFolder == nil && !launch.usesFakes)
    #expect(FlareWorkspace(launch: launch).document == nil)
}

@Test(arguments: [
    ["-FlareFixture"],
    ["-FlareFixture", "-FlareSaveTo", "/tmp/out"],
    ["-NSDocumentRevisionsDebugMode", "YES", "-FlareBogus", "bounce"],
    ["-FlareFixture", "nope"],
    ["-FlareSample", "nope"],
    ["-FlareFixture", ""],
])
func missingValuesUnknownFlagsAndNamesGiveNone(arguments: [String]) {
    let launch = FlareLaunch(arguments: arguments)
    #expect(launch.source == .none)
    #expect(!launch.usesFakes)
    #expect(FlareWorkspace(launch: launch).document == nil)
}

@Test func aFlagWithNoValueLeavesTheNextFlagRead() {
    let launch = FlareLaunch(arguments: ["-FlareSaveTo", "-FlareFixture", "bounce", "-FlareExportTo"])
    #expect(launch.saveFolder == nil && launch.exportFolder == nil)
    #expect(launch.source == .fixture("bounce"))
}

@Test func theLastSourceFlagWins() {
    #expect(FlareLaunch(arguments: ["-FlareFixture", "bounce", "-FlareSample", "character"]).source == .sample("character"))
    #expect(FlareLaunch(arguments: ["-FlareSample", "character", "-FlareOpenFile", "/tmp/a.flare"]).source == .file("/tmp/a.flare"))
    #expect(FlareLaunch(arguments: ["-FlareOpenFile", "/tmp/a.flare", "-FlareFixture", "button"]).source == .fixture("button"))
    #expect(FlareLaunch(arguments: ["-FlareFixture", "bounce", "-FlareFixture", "nope"]).source == .none)
    #expect(FlareLaunch(arguments: ["-FlareSaveTo", "/a", "-FlareSaveTo", "/b"]).saveFolder == "/b")
    let workspace = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce", "-FlareFixture", "character"]))
    #expect(workspace.document == FlareFixtures.named("character"))
    #expect(workspace.services.scenes is FakeScenes)
}
