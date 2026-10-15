// HaloCompositionFieldProblemTests.swift: each New Composition problem names
// the field it's about, so the sheet shows it under that field, and the
// composition size says its unit (pixels) in the sheet and the inspector.
// Runs on Linux and macOS.
import HaloModel
import Testing

@Test func eachProblemNamesItsField() {
    let settings = CompositionSettings(name: " ", width: 0, height: 9000, framesPerSecond: 7, durationSeconds: 0)
    #expect(settings.fieldProblems.map(\.field) == [.name, .width, .height, .frameRate, .duration])
    #expect(settings.fieldProblems.map(\.text) == settings.problems)
}

@Test func draftProblemsSitUnderTheFieldTheyAreAbout() {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.widthText = "abc"
    draft.durationText = "ten"
    #expect(draft.problems(for: .width) == ["Width must be a whole number of pixels."])
    #expect(draft.problems(for: .duration) == ["Duration must be a number of seconds."])
    #expect(draft.problems(for: .height).isEmpty)
    #expect(draft.problems(for: .name).isEmpty)
    #expect(draft.problems(for: .frameRate).isEmpty)
    #expect(CompositionField.allCases.flatMap { draft.problems(for: $0) } == draft.problems)
}

@Test func sizeSaysItsUnitIsPixels() {
    #expect(HaloComposition.sizeHelp == "Width × height in pixels.")
    #expect(HaloComposition.sizeUnit == "px")
}
