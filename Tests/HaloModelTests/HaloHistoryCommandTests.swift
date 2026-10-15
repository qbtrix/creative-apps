// HaloHistoryCommandTests.swift: HF-3, QB-F1 for Undo and Redo. Each acts
// or says why: "Nothing to undo." / "Nothing to redo." on an empty stack,
// "A project is opening." while a file opens, and the history service's own
// help while it can't act. Undo's title names its step. Linux and macOS.
import HaloModel
import Testing

/// A history service that can't act yet, so both commands carry its help.
private struct UnavailableHistory: ProjectHistory {
    var unavailableHelp: String? { "x" }
    var limit: Int { 0 }
    func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory) {}
    func endCoalescing(in history: inout HaloHistory) {}
    func undo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? { nil }
    func redo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? { nil }
}

private func empty(_ services: HaloServices = .live) throws -> HaloProject {
    HaloProject(services: services, document: try #require(HaloFixtures.project("empty")))
}

@Test func anEmptyHistorySaysThereIsNothingToUndoOrRedo() throws {
    let project = try empty()
    #expect(project.unavailableHelp(for: .undo) == "Nothing to undo.")
    #expect(project.unavailableHelp(for: .redo) == "Nothing to redo.")
}

@Test func anEditTurnsUndoOnAndNamesTheStep() throws {
    var project = try empty()
    project.newLayer(.solid)
    #expect(project.unavailableHelp(for: .undo) == nil)
    #expect(project.title(for: .undo) == "Undo New Layer")
    #expect(project.unavailableHelp(for: .redo) == "Nothing to redo.")
}

@Test func anOpeningProjectTurnsUndoAndRedoOff() throws {
    var project = try empty()
    project.newLayer(.solid)
    project.beginOpen(name: "Spot", path: "/t/Spot.halo")
    #expect(project.unavailableHelp(for: .undo) == "A project is opening.")
    #expect(project.unavailableHelp(for: .redo) == "A project is opening.")
}

@Test func anUnavailableHistoryServiceGivesItsHelp() throws {
    var services = HaloServices.live
    services.history = UnavailableHistory()
    let project = try empty(services)
    #expect(project.unavailableHelp(for: .undo) == "x")
    #expect(project.unavailableHelp(for: .redo) == "x")
}
