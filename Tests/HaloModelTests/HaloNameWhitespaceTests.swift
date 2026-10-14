// HaloNameWhitespaceTests.swift: names compare after collapsing inner
// whitespace runs to one space and dropping invisible format characters, and
// are stored that way, so a look-alike of a taken name is refused (#149).
// Runs on Linux and macOS.
import HaloModel
import Testing

/// A project with "Comp 1" (comp-1) and "Comp 2" (comp-2).
private func twoComps() -> HaloProject {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    return project
}

@Test(arguments: ["Comp\u{00A0}1", "Comp\u{2009}1", "Comp 1\u{200B}", "Comp 1\u{FEFF}", "Comp  1", "Comp\t1",
                  "\u{200B}Comp 1", "Co\u{00AD}mp 1", "Comp \u{2060} 1", "Comp\u{3000}1", "Comp\n1"])
func aWhitespaceOrFormatLookalikeIsTaken(typed: String) {
    var project = twoComps()
    #expect(project.renameProblem("comp-2", to: typed) != nil)
    #expect(project.renameComposition("comp-2", to: typed) == false)
    #expect(project.compositions.map(\.name) == ["Comp 1", "Comp 2"])
}

@Test func aRenamedNameIsStoredNormalized() {
    var project = twoComps()
    #expect(project.renameComposition("comp-2", to: "Comp\t3") == true)
    #expect(project.compositions.map(\.name) == ["Comp 1", "Comp 3"])
    #expect(project.renameComposition("comp-2", to: " \u{FEFF}Title\u{00A0}\u{00A0}card\u{200B} ") == true)
    #expect(project.compositions.map(\.name) == ["Comp 1", "Title card"])
}

@Test func aNewCompositionNameIsStoredNormalized() {
    var project = HaloProject()
    var settings = project.suggestedSettings
    settings.name = "Intro\t\tshot\u{200B}"
    #expect(project.newComposition(settings) == true)
    #expect(project.compositions.last?.name == "Intro shot")
    settings.name = "Intro  shot"
    #expect(project.newComposition(settings) == true)
    #expect(project.compositions.last?.name == "Intro shot 2")
}

@Test func anEmojiJoinerSurvivesAndAFormatOnlyNameIsEmpty() {
    var project = twoComps()
    let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"
    #expect(project.renameComposition("comp-2", to: "Team \(family)") == true)
    #expect(project.compositions.map(\.name) == ["Comp 1", "Team \(family)"])
    #expect(project.renameProblem("comp-2", to: "\u{200B}\u{FEFF}\u{00A0}") == "Enter a name for the composition.")
}
