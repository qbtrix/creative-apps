// HaloProjectLaunchTests.swift: `HaloProject(services:document:)`, how the
// app opens a fixture at launch: the document is the fixture's, with no undo
// step, nothing unsaved and no refusal, and edits on it record as usual.
// Runs on Linux and macOS.
import HaloModel
import Testing

@Test(arguments: HaloFixtures.names.filter { $0 != "huge" })
func launchOpensTheFixtureWithNoHistory(name: String) throws {
    let document = try #require(HaloFixtures.project(name))
    let project = HaloProject(services: .fake, document: document)
    #expect(project.document == document)
    #expect(project.history == HaloHistory())
    #expect(!project.file.unsaved)
    #expect(project.refusal == nil)
    #expect(project.selectedCompositionID == document.selectedCompositionID)
}

@Test func anEditAfterLaunchIsOneStep() throws {
    let document = try #require(HaloFixtures.project("keyed"))
    var project = HaloProject(services: .fake, document: document)
    project.newLayer(.solid)
    #expect(project.history.undo.count == 1)
    #expect(project.file.unsaved)
    #expect(project.compositions.first?.layers.count == 3)
}

@Test func launchKeepsTheServicesItWasGiven() throws {
    let document = try #require(HaloFixtures.project("empty"))
    var services = HaloServices.live
    services.text = FakeTextRasterizer()
    let project = HaloProject(services: services, document: document)
    #expect(project.services.text is FakeTextRasterizer)
    #expect(project.services.history is LiveProjectHistory)
    #expect(project.compositions.map(\.name) == ["Comp 1"])
}
