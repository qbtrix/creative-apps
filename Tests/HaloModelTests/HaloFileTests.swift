// HaloFileTests.swift: the project's file state (HaloFiles.swift) on the
// live services: opening replaces the document and clears history, a failed
// open changes nothing, saves keep a recent list of 10 with no repeated path,
// and the window title and save status read what the window shows.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HaloModel
import Testing

private func opened(_ name: String = "two-comps") throws -> (HaloProject, HaloDocumentState) {
    let fixture = try #require(HaloFixtures.project(name))
    var project = HaloProject(services: .live, document: fixture)
    let decoded = try project.services.files.decode(project.fileData())
    project.beginOpen(name: "Spot", path: "/t/Spot.halo")
    project.finishOpen(.success(decoded))
    return (project, fixture)
}

@Test func openingReplacesTheDocumentAndClearsHistory() throws {
    let (project, fixture) = try opened()
    #expect(project.document == fixture)
    #expect(project.history == HaloHistory())
    #expect(project.windowTitle == "Spot")
    #expect(project.saveStatus == "Saved")
    #expect(project.recent.first == HaloRecentFile(name: "Spot", path: "/t/Spot.halo"))
    #expect(project.recent.count == 1)
    #expect(!project.file.opening && project.file.error == nil)
}

@Test func openingClearsRealUndoSteps() throws {
    var project = HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
    project.newLayer(.solid)
    project.newLayer(.shape)
    #expect(project.history.undo.count == 2)
    let decoded = try project.services.files.decode(project.fileData())
    project.beginOpen(name: "Spot", path: "/t/Spot.halo")
    #expect(project.file.opening && project.recent.isEmpty)
    project.finishOpen(.success(decoded))
    #expect(project.history == HaloHistory())
    #expect(!project.file.unsaved)
}

@Test func aFailedOpenLeavesTheProjectAsItWas() throws {
    var (project, _) = try opened()
    project.newLayer(.solid)
    let before = project
    project.beginOpen(name: "Next", path: "/t/Next.halo")
    project.finishOpen(.failure(.newerVersion(2)))
    #expect(project.document == before.document)
    #expect(project.history == before.history)
    #expect(project.file.error == HaloFileError.newerVersion(2).message)
    #expect(!project.file.opening)
    #expect(project.recent == before.recent)
    #expect(project.windowTitle == "Spot")
}

@Test func anEditAfterSavingReadsEdited() throws {
    var project = HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
    #expect(project.saveStatus == "Untitled")
    project.didSave(name: "Spot", path: "/t/Spot.halo")
    #expect(project.saveStatus == "Saved")
    project.newLayer(.solid)
    #expect(project.saveStatus == "Edited")
    project.didFailSave("The disk is full.")
    #expect(project.saveStatus == "Not saved")
    #expect(project.file.unsaved && project.file.error == "The disk is full.")
    #expect(project.windowTitle == "Spot")
}

@Test func recentKeepsTenNewestFirstWithNoRepeat() throws {
    var project = HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
    for i in 1...11 { project.didSave(name: "P\(i)", path: "/t/P\(i).halo") }
    #expect(project.recent.count == 10)
    #expect(project.recent.map(\.name) == (2...11).reversed().map { "P\($0)" })
    let third = try #require(project.recent.dropFirst(2).first)
    project.didSave(name: third.name, path: third.path)
    #expect(project.recent.first == third)
    #expect(project.recent.count == 10)
    #expect(project.recent.filter { $0.path == third.path }.count == 1)
}

@Test func setRecentKeepsTenAndDropsRepeats() {
    var project = HaloProject()
    let files = (1...12).map { HaloRecentFile(name: "P\($0)", path: "/t/P\($0 % 11).halo") }
    project.setRecent(files)
    #expect(project.recent.count == 10)
    #expect(Set(project.recent.map(\.path)).count == 10)
    #expect(project.recent.first?.name == "P1")
}

@Test func windowTitleBeforeAnyFile() throws {
    #expect(HaloProject().windowTitle == "Halo")
    let empty = HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
    #expect(empty.windowTitle == "Untitled Project")
}

@Test func fileDataIsTheLiveEncoding() throws {
    let project = HaloProject(services: .live, document: try #require(HaloFixtures.project("two-comps")))
    #expect(try project.fileData() == project.services.files.encode(project.document))
}
