// HaloFileTests.swift: the project's file state (HaloFiles.swift) on the
// live services: opening replaces the document and clears history, a failed
// open changes nothing, an open holds its file in `file.pending` until it
// ends, and the window title, subtitle and save status read what the window shows.
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
    #expect(project.file.path == "/t/Spot.halo")
    #expect(project.file.pending == nil, "the open left its file pending")
    #expect(!project.file.opening && project.file.error == nil)
}

@Test func openingClearsRealUndoSteps() throws {
    var project = HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
    project.newLayer(.solid)
    project.newLayer(.shape)
    #expect(project.history.undo.count == 2)
    let decoded = try project.services.files.decode(project.fileData())
    project.beginOpen(name: "Spot", path: "/t/Spot.halo")
    #expect(project.file.opening && project.file.pending == HaloFileRef(name: "Spot", path: "/t/Spot.halo"))
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
    #expect(project.file.path == before.file.path && project.file.pending == nil)
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

@Test func windowSubtitleShowsOnlyUnsavedWork() throws {
    var project = HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
    #expect(project.windowSubtitle == nil)
    project.newLayer(.solid)
    #expect(project.windowSubtitle == "Edited")
    project.didSave(name: "Spot", path: "/t/Spot.halo")
    #expect(project.windowSubtitle == nil)
    project.newLayer(.solid)
    project.didFailSave("The disk is full.")
    #expect(project.windowSubtitle == "Not saved")
    project.didSave(name: "Spot", path: "/t/Spot.halo")
    #expect(project.windowSubtitle == nil)
    #expect(project.windowTitle == "Spot")
}

@Test func aFailedOpenAddsNoSubtitle() throws {
    var (project, _) = try opened()
    project.beginOpen(name: "Next", path: "/t/Next.halo")
    project.finishOpen(.failure(.notAHaloFile))
    #expect(project.windowSubtitle == nil)
    #expect(project.saveStatus == "Saved")
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
