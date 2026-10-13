// HaloRenameLookalikeEdgeTests.swift: edge cases around the look-alike name
// refusal from #138: canonical equivalents beyond accents, a project of three,
// renaming to one's own name, and names freed by delete. Runs on Linux and macOS.
import HaloModel
import Testing

/// A project with "Comp 1", "Comp 2" and "Comp 3" (comp-1 ... comp-3).
private func threeCompositions() -> HaloProject {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    project.newComposition()
    return project
}

@Test func canonicalEquivalentsBeyondAccentsAreTheSameName() {
    var project = threeCompositions()
    #expect(project.renameComposition("comp-1", to: "\u{D55C}") == true)  // Hangul syllable
    #expect(project.renameComposition("comp-2", to: "\u{C5}ngstr\u{F6}m") == true)
    // Conjoining jamo spell the same syllable; the angstrom sign is canonically the letter.
    #expect(project.renameComposition("comp-3", to: "\u{1112}\u{1161}\u{11AB}") == false)
    #expect(project.renameComposition("comp-3", to: "\u{212B}ngstro\u{308}m") == false)
    #expect(project.compositions.map(\.name) == ["\u{D55C}", "\u{C5}ngstr\u{F6}m", "Comp 3"])
}

@Test func aLookalikeOfAnyOtherCompositionIsTakenAndTheTypedNameIsKept() {
    var project = threeCompositions()
    #expect(project.renameComposition("comp-3", to: "\n comp 1 \t") == false)
    #expect(project.refusedRename?.id == "comp-3")
    #expect(project.refusedRename?.name == "\n comp 1 \t")
    #expect(project.refusedRename?.problem == "“comp 1” is already used by another composition. Choose a different name.")
    #expect(project.compositions.map(\.name) == ["Comp 1", "Comp 2", "Comp 3"])
}

@Test func recasingYourOwnNameIsAllowedAndStoredTrimmed() {
    var project = threeCompositions()
    #expect(project.renameProblem("comp-2", to: "Comp 2") == nil)
    #expect(project.renameComposition("comp-2", to: "\t COMP 2 \n") == true)
    #expect(project.refusedRename == nil)
    #expect(project.compositions.map(\.name) == ["Comp 1", "COMP 2", "Comp 3"])
}

@Test func deletingACompositionFreesItsNameForLookalikes() {
    var project = threeCompositions()
    #expect(project.renameComposition("comp-3", to: "comp 1") == false)
    let deleted = project.deleteComposition("comp-1")
    #expect(deleted)
    #expect(project.renameComposition("comp-3", to: "comp 1") == true)
    #expect(project.compositions.map(\.name) == ["Comp 2", "comp 1"])
}

@Test func anUnknownCompositionIsReportedBeforeATakenName() {
    let project = threeCompositions()
    #expect(project.renameProblem("comp-9", to: "COMP 1") == "The composition no longer exists.")
}
