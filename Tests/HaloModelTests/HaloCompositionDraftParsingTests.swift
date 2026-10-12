// HaloCompositionDraftParsingTests.swift: the New Composition draft tells text
// that isn't a number apart from a number outside the range, so the problem
// line points at the right fix. Runs on Linux and macOS.
import HaloModel
import Testing

private let widthRange = "Width must be 1 to 8192 pixels."
private let widthWhole = "Width must be a whole number of pixels."

@Test(arguments: ["1920.0", "1920.", " 1920.00 ", "+1920.0"])
func wholeValuedDecimalWidthIsAccepted(text: String) {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.widthText = text
    draft.heightText = text
    #expect(draft.settings.width == 1920)
    #expect(draft.settings.height == 1920)
    #expect(draft.problems.isEmpty)
}

@Test(arguments: ["1,920", "1e3", "1920.5", "1 920", "0x10", "wide", "", ".", ".0", "1920px"])
func widthThatIsNotAWholeNumberSaysSo(text: String) {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.widthText = text
    draft.heightText = text
    #expect(draft.problems == [widthWhole, "Height must be a whole number of pixels."])
    #expect(!draft.isValid)
}

@Test(arguments: [
    "0", "8193", "-1", "-0", "0.0", "8193.0", "9223372036854775807", "9223372036854775808", "-99999999999999999999",
])
func wholeWidthOutsideTheRangeGivesTheRange(text: String) {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.widthText = text
    #expect(draft.problems == [widthRange])
    #expect(!draft.isValid)
}

@Test func widthPastIntGivesTheRangeAndBlocksCreate() {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.widthText = "99999999999999999999"
    #expect(draft.problems == [widthRange])
    var project = HaloProject()
    #expect(project.newComposition(draft.settings) == false)
    #expect(project == HaloProject())
}

@Test(arguments: ["ten", "2.5s", "..", ""])
func durationThatIsNotANumberSaysSo(text: String) {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.durationText = text
    #expect(draft.problems == ["Duration must be a number of seconds."])
}

@Test(arguments: ["0", "-5", "86401", "inf", "NaN"])
func durationNumberOutsideTheRangeGivesTheRange(text: String) {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.durationText = text
    #expect(draft.problems == ["Duration must be more than 0 seconds and at most 24 hours."])
}
