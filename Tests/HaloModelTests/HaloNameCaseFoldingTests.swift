// HaloNameCaseFoldingTests.swift: names compare case folded, not just
// lowercased, so STRASSE and straße are the same name for renaming and for
// New Composition and Duplicate numbering (#151). Runs on Linux and macOS.
import HaloModel
import Testing

/// A project with comp-1 renamed to `first` and comp-2 renamed to `second`.
private func project(_ first: String, _ second: String) -> HaloProject {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    project.renameComposition("comp-1", to: first)
    project.renameComposition("comp-2", to: second)
    return project
}

@Test(arguments: [("STRASSE", "stra\u{DF}e"), ("stra\u{DF}e", "STRASSE"), ("Ma\u{DF}", "MASS")])
func renamingToASharpSLookalikeIsRefused(taken: String, typed: String) {
    let project = project(taken, "Other")
    #expect(project.renameProblem("comp-2", to: typed) != nil)
}

@Test func newCompositionNumbersASharpSLookalike() {
    var project = project("STRASSE", "Other")
    let added = project.newComposition(CompositionSettings(name: "stra\u{DF}e"))
    #expect(added)
    #expect(project.compositions.last?.name == "stra\u{DF}e 2")
}

@Test func duplicateNumbersPastASharpSLookalikeCopyName() {
    var project = project("Stra\u{DF}e", "STRASSE COPY")
    let duplicated = project.duplicateComposition("comp-1")
    #expect(duplicated)
    #expect(project.compositions.map(\.name) == ["Stra\u{DF}e", "Stra\u{DF}e copy 2", "STRASSE COPY"])
}

@Test func composedDecomposedAndPaddedNamesStillMatch() {
    let project = project("CAF\u{C9}", "Other")
    #expect(project.renameProblem("comp-2", to: "  cafe\u{301}\t") != nil)
    #expect(project.renameProblem("comp-2", to: " caf\u{E9} ") != nil)
}

@Test func recasingYourOwnSharpSNameIsAllowed() {
    var project = project("stra\u{DF}e", "Other")
    #expect(project.renameProblem("comp-1", to: "STRASSE") == nil)
    project.renameComposition("comp-1", to: "STRASSE")
    #expect(project.compositions.first?.name == "STRASSE")
}

@Test func namesThatOnlyLookCloseStayDistinct() {
    let project = project("Strasse", "Other")
    #expect(project.renameProblem("comp-2", to: "Strase") == nil)
    #expect(project.renameProblem("comp-2", to: "Stra\u{DF}") == nil)
}
