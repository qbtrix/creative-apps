// HaloCompositionDraftTests.swift: the New Composition draft reads its numbers
// from the typed text, so validation and Create see the latest edit, never a
// stale value. Runs on Linux and macOS.
import HaloModel
import Testing

@Test func draftStartsFromTheSettingsAsText() {
    let draft = CompositionDraft(CompositionSettings(name: "Comp 1", durationSeconds: 2.5))
    #expect(draft.widthText == "1920")
    #expect(draft.heightText == "1080")
    #expect(draft.durationText == "2.5")
    #expect(CompositionDraft(CompositionSettings(name: "Comp 1")).durationText == "10")
    #expect(draft.settings == CompositionSettings(name: "Comp 1", durationSeconds: 2.5))
}

@Test func editedTextIsWhatValidationAndCreateSee() {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.widthText = "0"
    #expect(!draft.isValid)
    #expect(draft.problems == ["Width must be 1 to 8192 pixels."])
    draft.widthText = " 1280 "
    draft.heightText = "720"
    draft.durationText = "3.5"
    #expect(draft.isValid)
    #expect(draft.settings == CompositionSettings(name: "Intro", width: 1280, height: 720, durationSeconds: 3.5))
    var project = HaloProject()
    #expect(project.newComposition(draft.settings) == true)
    #expect(project.selectedComposition?.width == 1280)
}

@Test(arguments: [
    ("abc", "1080", "10", "Width must be a whole number of pixels."), ("", "1080", "10", "Width must be a whole number of pixels."),
    ("1920.5", "1080", "10", "Width must be a whole number of pixels."), ("1920", "99999999999999999999", "10", "Height must be 1 to 8192 pixels."),
    ("1920", "1080", "", "Duration must be a number of seconds."),
    ("1920", "1080", "nan", "Duration must be more than 0 seconds and at most 24 hours."),
    ("1920", "1080", "ten", "Duration must be a number of seconds."),
])
func textThatIsNotANumberIsInvalid(width: String, height: String, duration: String, problem: String) {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.widthText = width
    draft.heightText = height
    draft.durationText = duration
    #expect(!draft.isValid)
    #expect(draft.problems == [problem])
}
