// HaloCompositionDraftEdgeTests.swift: adversarial and seeded-fuzz tests for
// the New Composition draft. Every keystroke is in the draft, so validation and
// Create follow the latest text and never fall back to an older value. Runs on
// Linux and macOS.
import HaloModel
import Testing

@Test func typingAnOutOfRangeWidthBlocksCreateWithoutReturn() {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    var project = HaloProject()
    for text in ["", "9", "99", "999", "9999", "99999"] {
        draft.widthText = text
        #expect(draft.settings.width == (Int(text) ?? 0))
    }
    #expect(!draft.isValid)
    #expect(draft.problems == ["Width must be 1 to 8192 pixels."])
    #expect(project.newComposition(draft.settings) == false)
    #expect(project == HaloProject())
}

@Test func fixingAnInvalidFieldEnablesCreateOnTheKeystroke() {
    var draft = CompositionDraft(CompositionSettings(name: "Intro", width: 0, height: 0, durationSeconds: 0))
    #expect(draft.problems.count == 3)
    draft.widthText = "640"
    draft.heightText = "480"
    #expect(draft.problems == ["Duration must be more than 0 seconds and at most 24 hours."])
    draft.durationText = "1"
    #expect(draft.isValid)
    var project = HaloProject()
    #expect(project.newComposition(draft.settings) == true)
    #expect(project.selectedComposition?.width == 640)
    #expect(project.selectedComposition?.height == 480)
    #expect(project.selectedComposition?.durationFrames == 30)
}

@Test(arguments: [
    ("1", true), ("8192", true), ("0", false), ("8193", false), ("-1", false), ("-0", false),
    ("+1920", true), ("9223372036854775807", false), ("9223372036854775808", false),
    ("0x10", false), ("1 920", false), ("\t1920\n", true), ("\u{00A0}1920\u{00A0}", true),
])
func widthTextAtTheEdges(text: String, valid: Bool) {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.widthText = text
    draft.heightText = text
    #expect(draft.isValid == valid)
    #expect(draft.problems.isEmpty == valid)
}

@Test(arguments: [
    ("86400", true), ("86400.0000001", false), ("0.001", true), ("0", false), ("-0", false), ("-5", false),
    ("inf", false), ("-inf", false), ("infinity", false), ("NaN", false), ("1e309", false), ("1e-400", false),
    (" 2.5 ", true), ("2.5s", false), ("..", false),
])
func durationTextAtTheEdges(text: String, valid: Bool) {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.durationText = text
    #expect(draft.isValid == valid)
    #expect(draft.settings.durationFrames == nil || valid)
}

@Test func everyBadFieldGivesItsLineInFormOrder() {
    var draft = CompositionDraft(CompositionSettings(name: "Intro"))
    draft.name = "   "
    draft.widthText = "wide"
    draft.heightText = ""
    draft.framesPerSecond = 29
    draft.durationText = "long"
    #expect(draft.problems == [
        "Enter a name.", "Width must be 1 to 8192 pixels.", "Height must be 1 to 8192 pixels.",
        "Frame rate must be 24, 25, 30 or 60 fps.", "Duration must be more than 0 seconds and at most 24 hours.",
    ])
}

@Test(arguments: [0.1, 1.0 / 3.0, 59.97, 86_400, 1e-9, 12_345.678_9])
func durationTextRoundTripsTheSettings(seconds: Double) {
    let settings = CompositionSettings(name: "Intro", durationSeconds: seconds)
    #expect(CompositionDraft(settings).settings == settings)
}

/// A small deterministic generator (SplitMix64) so a failing fuzz run repeats.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Test(arguments: [3, 11, 128, 4096, 65_537] as [UInt64])
func randomTypingAlwaysValidatesTheLatestText(seed: UInt64) {
    var rng = SplitMix64(state: seed)
    let keys = Array("0123456789 .-+eE,x")
    var draft = CompositionDraft(CompositionSettings(name: "Comp 1"))
    for _ in 0..<300 {
        let text = String((0..<Int.random(in: 0...7, using: &rng)).compactMap { _ in keys.randomElement(using: &rng) })
        switch Int.random(in: 0..<3, using: &rng) {
        case 0: draft.widthText = text
        case 1: draft.heightText = text
        default: draft.durationText = text
        }
        let width = Int(draft.widthText.filter { !$0.isWhitespace }) ?? 0
        let height = Int(draft.heightText.filter { !$0.isWhitespace }) ?? 0
        if !draft.widthText.contains(" ") { #expect(draft.settings.width == width) }
        if !draft.heightText.contains(" ") { #expect(draft.settings.height == height) }
        #expect(draft.isValid == draft.settings.isValid)
        #expect(draft.problems == draft.settings.problems)
        var project = HaloProject()
        let before = project
        if project.newComposition(draft.settings) {
            #expect(draft.isValid)
            #expect(project.selectedComposition?.width == draft.settings.width)
            #expect(project.selectedComposition?.height == draft.settings.height)
            #expect((project.selectedComposition?.durationFrames ?? 0) >= 1)
        } else {
            #expect(!draft.isValid)
            #expect(project == before)
        }
    }
}
