// HaloUniqueNameLookalikeTests.swift: New Composition and Duplicate never
// make a name that renaming would refuse as taken; a look-alike of an
// existing name gets a number (#150). Runs on Linux and macOS.
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

@Test func newCompositionNumbersALookalikeOfAnExistingName() {
    var project = project("CAF\u{C9}", "Other")
    let added = project.newComposition(CompositionSettings(name: " Cafe\u{301} "))
    #expect(added)
    #expect(project.compositions.last?.name == "Cafe\u{301} 2")
    #expect(project.renameProblem("comp-2", to: "CAF\u{C9} 2") != nil)
}

@Test func theSuggestedNameSkipsALookalikeOfTheNextNumber() {
    var project = project("comp 3", "COMP 3 2")
    #expect(project.suggestedSettings.name == "Comp 3 3")
    project.newComposition()
    #expect(project.compositions.map(\.name) == ["comp 3", "COMP 3 2", "Comp 3 3"])
}

@Test func duplicateNumbersPastALookalikeCopyName() {
    var project = project("Title", "TITLE COPY")
    let duplicated = project.duplicateComposition("comp-1")
    #expect(duplicated)
    #expect(project.compositions.map(\.name) == ["Title", "Title copy 2", "TITLE COPY"])
    for comp in project.compositions {
        #expect(project.renameProblem(comp.id, to: comp.name) == nil)
    }
}

@Test func distinctNamesAreKeptAsTyped() {
    var project = project("Cafe", "Title")
    let added = project.newComposition(CompositionSettings(name: "Caf\u{E9}"))
    let duplicated = project.duplicateComposition("comp-2")
    #expect(added && duplicated)
    #expect(project.compositions.map(\.name) == ["Cafe", "Title", "Title copy", "Caf\u{E9}"])
}
