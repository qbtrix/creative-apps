// HaloRenameLookalikeTests.swift: a composition name that looks the same as
// another one (case, surrounding whitespace, composed or decomposed accents)
// is refused as taken (#138). Runs on Linux and macOS.
import HaloModel
import Testing

/// A project with "Comp 1" (comp-1) and comp-2 renamed to `name`.
private func project(secondNamed name: String) -> HaloProject {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    project.renameComposition("comp-2", to: name)
    return project
}

@Test func aNameThatDiffersOnlyInCaseIsTaken() {
    var project = project(secondNamed: "Comp 2")
    #expect(project.renameProblem("comp-2", to: "COMP 1") == "“COMP 1” is already used by another composition. Choose a different name.")
    #expect(project.renameComposition("comp-2", to: "comp 1") == false)
    #expect(project.compositions.map(\.name) == ["Comp 1", "Comp 2"])
}

@Test func composedAndDecomposedAccentsAreTheSameName() {
    var project = project(secondNamed: "Caf\u{E9}")
    #expect(project.renameComposition("comp-1", to: "Cafe\u{301}") == false)
    #expect(project.renameComposition("comp-1", to: "  CAFE\u{301}\t") == false)
    #expect(project.refusedRename?.problem == "“CAFE\u{301}” is already used by another composition. Choose a different name.")
    #expect(project.compositions.map(\.name) == ["Comp 1", "Caf\u{E9}"])
}

@Test func aDistinctNameAndARecasingOfItsOwnNameAreAllowed() {
    var project = project(secondNamed: "Caf\u{E9}")
    #expect(project.renameProblem("comp-1", to: "Cafe") == nil)
    #expect(project.renameComposition("comp-2", to: " CAF\u{C9} ") == true)
    #expect(project.compositions.map(\.name) == ["Comp 1", "CAF\u{C9}"])
}
