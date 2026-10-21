// HaloRecoveryTests.swift (autosave-history HA-1, HA-5, MJ-HA): the History
// panel's listing and the recovery bytes, through HaloRecovery+Kernel.swift. A
// new project lists "New Project", an opened one "Open", each edit a step and
// undo moves the index without dropping it; the saved mark follows a save; the
// recovery bytes are the bytes Save writes. HA-5's bodies: a jump to 4 of 10
// key edits restores those keys and records nothing; recovery bytes reopen
// dirty and never saved; damaged bytes throw. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import HaloModel
import SuiteKernel
import Testing

/// `keyed` on live services with Ball selected at frame 0, no steps yet.
private func ball() throws -> HaloProject {
    var project = HaloProject(services: .live, document: try #require(HaloFixtures.project("keyed")))
    let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" })
    project.selectLayer(ball.id)
    return project
}

/// Ten typed x values on Ball, at frames 0...9: one step each.
private func keyTen(_ project: inout HaloProject) {
    for frame in 0..<10 {
        project.scrub(to: frame)
        project.setProperty(.x, text: "\(100 + frame * 10)")
    }
}

@Test func aNewProjectListsNewProjectAndNoSteps() {
    let listing = HaloProject(services: .live).historyListing
    #expect(listing.base == "New Project")
    #expect(listing.steps.isEmpty)
    #expect(listing.index == 0)
}

@Test func eachEditIsAStepAndUndoMovesTheIndexOnly() throws {
    var project = try ball()
    keyTen(&project)
    #expect(project.historyListing.steps == Array(repeating: "Change Position X", count: 10))
    #expect(project.historyListing.index == 10)
    project.undo()
    #expect(project.historyListing.steps.count == 10)
    #expect(project.historyListing.index == 9)
}

@Test func anOpenedProjectListsOpenAndASaveMarksItsStep() throws {
    var project = HaloProject(services: .live)
    project.beginOpen(name: "title", path: "/t/title.halo")
    project.finishOpen(.success(try #require(HaloFixtures.project("keyed"))))
    #expect(project.historyListing.base == "Open")
    #expect(project.historyListing.savedIndex == 0)
    let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" })
    project.selectLayer(ball.id)
    project.setProperty(.x, text: "120")
    project.didSave(name: "title", path: "/t/title.halo")
    #expect(project.historyListing.savedIndex == 1)
}

@Test func recoveryBytesAreTheBytesSaveWrites() throws {
    var project = try ball()
    keyTen(&project)
    #expect(try project.recoveryBytes() == project.fileData())
}

@Test func jumpRecordsNothing() throws {
    var project = try ball()
    keyTen(&project)
    var four = try ball()
    for frame in 0..<4 {
        four.scrub(to: frame)
        four.setProperty(.x, text: "\(100 + frame * 10)")
    }
    let before = project.historyListing
    try project.jumpHistory(to: 4)
    #expect(project.selectedComposition?.layers == four.selectedComposition?.layers)
    #expect(project.historyListing.steps == before.steps)
    #expect(project.historyListing.index == 4)
    try project.jumpHistory(to: 10)
    #expect(project.historyListing.index == 10)
    #expect(project.historyListing.steps.count == 10)
}

@Test func recoveryBytesReopenDirtyAndNeverSaved() throws {
    var project = try ball()
    keyTen(&project)
    let reopened = try HaloProject.recovered(from: project.recoveryBytes(), name: "title")
    #expect(reopened.compositions == project.compositions)
    #expect(reopened.file.unsaved)
    #expect(reopened.file.path == nil)
    #expect(reopened.windowTitle == "title")
    #expect(reopened.historyListing.steps.isEmpty)
}

@Test func damagedBytesThrow() throws {
    #expect(throws: (any Error).self) { try HaloProject.recovered(from: Data("not a halo file".utf8), name: nil) }
    #expect(throws: (any Error).self) { try HaloProject.recovered(from: Data(), name: "title") }
}
