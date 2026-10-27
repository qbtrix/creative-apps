// TextStyleRowsTests.swift: SuiteUI's text style rows (text-style TS-2). Each
// control asks for exactly one TextIntent and never edits a document: a family
// or face pick one `.font`, a size pick one `.size`, Italic one `.font` with
// the face flipped, each of the four alignment buttons one `.alignment`
// (Justify the fourth), Line Height and Letter Spacing one scrub intent under
// the gesture's drag token, clamped to TextStyleRules' ranges; a value that
// changes nothing asks for none. With no style, or `help`, every control is
// disabled and says why; Italic is disabled on a family without the other
// face. Every control carries a `suite.text.<field>` id. No rendering. macOS only.
import AppKit
import SuiteKernel
import SuiteModel
import Testing

@testable import SuiteUI

private let helvetica = FontFamily(name: "Helvetica", faces: [
    FontFace(name: "Regular", weight: 400, italic: false), FontFace(name: "Oblique", weight: 400, italic: true),
    FontFace(name: "Bold", weight: 700, italic: false),
])
private let uprightOnly = FontFamily(name: "Upright", faces: [FontFace(name: "Regular", weight: 400, italic: false)])
private let style = TextStyle(family: "Helvetica", weight: 400, italic: false, size: 24, rgba: [0, 0, 0, 255],
                              paragraph: ParagraphStyle(alignment: .leading, lineHeight: 1.2, tracking: 0))

@Test func thePickReadsTheStyleFace() {
    let pick = TextStyleRows.pick(style, families: [helvetica])
    #expect(pick == FontPick(family: "Helvetica", face: FontFace(name: "Regular", weight: 400, italic: false), size: 24))
    let system = TextStyleRows.pick(.standard, families: [helvetica])
    #expect(system == FontPick(family: "System", face: FontFace(name: "Regular", weight: 400, italic: false), size: 24))
    var bold = TextStyle.standard
    (bold.weight, bold.italic) = (700, true)
    #expect(TextStyleRows.pick(bold, families: []).face.name == "Bold Italic")
}

@Test func aFamilyOrFacePickAsksForOneFont() {
    let pick = TextStyleRows.pick(style, families: [helvetica])
    var bold = pick
    bold.face = FontFace(name: "Bold", weight: 700, italic: false)
    #expect(TextStyleRows.intents(from: pick, to: bold) == [.font(family: "Helvetica", weight: 700, italic: false)])
    var other = pick
    other.family = "Upright"
    #expect(TextStyleRows.intents(from: pick, to: other) == [.font(family: "Upright", weight: 400, italic: false)])
    #expect(TextStyleRows.intents(from: pick, to: pick) == [])
}

@Test func aSizePickAsksForOneSize() {
    let pick = TextStyleRows.pick(style, families: [helvetica])
    var bigger = pick
    bigger.size = 36
    #expect(TextStyleRows.intents(from: pick, to: bigger) == [.size(36, drag: nil)])
}

@Test func italicFlipsTheFaceAndIsDisabledWithoutOne() {
    #expect(TextStyleRows.italicIntent(style, on: true) == .font(family: "Helvetica", weight: 400, italic: true))
    #expect(TextStyleRows.italicIntent(style, on: false) == nil)
    #expect(TextStyleRows.italicReason(style, families: [helvetica]) == nil)
    var upright = style
    upright.family = "Upright"
    #expect(TextStyleRows.italicReason(upright, families: [uprightOnly]) == TextStyleRows.noItalic)
    var slanted = upright
    slanted.italic = true
    #expect(TextStyleRows.italicReason(slanted, families: [uprightOnly]) == nil)
    #expect(TextStyleRows.italicReason(.standard, families: [uprightOnly]) == nil)
}

@Test @MainActor func eachAlignmentButtonAsksForItsAlignmentAndJustifyIsFourth() {
    var asked = [TextIntent]()
    let actions = TextStyleRows.alignments(style, reason: nil) { asked.append($0) }
    #expect(actions.map(\.title) == ["Align Left", "Align Center", "Align Right", "Justify"])
    #expect(actions.map(\.systemImage) == ["text.alignleft", "text.aligncenter", "text.alignright", "text.justify"])
    #expect(actions.map(\.identifier) == ["suite.text.alignment.leading", "suite.text.alignment.center",
                                          "suite.text.alignment.trailing", "suite.text.alignment.justified"])
    #expect(actions.map(\.isSelected) == [true, false, false, false])
    actions.forEach { $0.perform() }
    #expect(asked == [.alignment(.center), .alignment(.trailing), .alignment(.justified)])
}

@Test func theScrubsClampAndCarryTheDragToken() {
    #expect(TextStyleRows.intent(.lineHeight, to: 1.5, from: style, drag: "d") == .lineHeight(1.5, drag: "d"))
    #expect(TextStyleRows.intent(.tracking, to: 20, from: style, drag: "d") == .tracking(20, drag: "d"))
    #expect(TextStyleRows.intent(.lineHeight, to: 9, from: style, drag: nil) == .lineHeight(4, drag: nil))
    #expect(TextStyleRows.intent(.tracking, to: -500, from: style, drag: nil) == .tracking(-100, drag: nil))
    #expect(TextStyleRows.intent(.lineHeight, to: 1.2, from: style, drag: nil) == nil)
    #expect(TextStyleRows.intent(.tracking, to: .nan, from: style, drag: nil) == nil)
}

@Test func theValuesFormatAsThePacketSays() {
    #expect(TextStyleRows.scrubs.map(\.title) == ["Line Height", "Letter Spacing"])
    #expect(TextStyleRows.decimals(.lineHeight) == 2 && TextStyleRows.decimals(.tracking) == 0)
    #expect(TextStyleRows.unit(.lineHeight) == "×" && TextStyleRows.unit(.tracking) == "")
    #expect(TextStyleRows.value(.lineHeight, of: style) == 1.2 && TextStyleRows.value(.tracking, of: style) == 0)
}

@Test @MainActor func noStyleOrHelpDisablesEveryControlAndSaysWhy() {
    #expect(TextStyleRows.reason(style: nil, help: nil) == "Select a text layer first.")
    #expect(TextStyleRows.reason(style: style, help: "Locked") == "Locked")
    #expect(TextStyleRows.reason(style: style, help: nil) == nil)
    let actions = TextStyleRows.alignments(style, reason: "Locked") { _ in }
    #expect(actions.allSatisfy { !$0.isEnabled && $0.help == "Locked" })
}

@Test func everyControlCarriesATextID() {
    #expect(TextStyleRows.controlIDs == ["suite.text.font", "suite.text.italic", "suite.text.alignment",
                                         "suite.text.line-height", "suite.text.tracking"])
    #expect(TextStyleRows.scrubs.map(\.id) == ["suite.text.line-height", "suite.text.tracking"])
}
