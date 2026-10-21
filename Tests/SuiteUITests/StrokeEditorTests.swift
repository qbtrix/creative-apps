// StrokeEditorTests.swift: SuiteUI's StrokeEditor (stroke-style SS-3) through StrokeEditorRules, the decisions its
// rows make. A width scrub asks for `.width`s under one drag token, and the next scrub for a new one; Round join asks
// for one `.join(.round)`, Dashed for one `.dash(.dashed, nil)`, and a chip already on asks for nothing; with
// `dashHelp` set the dash and trim rows are disabled with it and ask for nothing; `showsTrim: false` hides the trim
// rows; without a stroke Add Stroke is the one row; each join and cap option has a tooltip line; Width reads "4 pt" or
// "0.5 pt". No rendering. macOS only.
import SuiteKernel
import Testing

@testable import SuiteUI

private let waiting = StrokeRules.waitingCore
private func rules(_ stroke: VectorStroke? = VectorStroke(width: 2), help: String? = nil, dashHelp: String? = nil,
                   showsTrim: Bool = true) -> StrokeEditorRules {
    StrokeEditorRules(stroke: stroke, help: help, dashHelp: dashHelp, showsTrim: showsTrim)
}

/// A scrub as the view runs it: the open token (opened on the first sample), then the sample's intent.
private func scrub(_ values: [Double], _ intent: (Double, String) -> StrokeIntent?) -> [StrokeIntent] {
    var open: String?
    return values.compactMap { value in
        let token = StrokeEditorRules.token(open)
        open = token
        return intent(value, token)
    }
}

@Test func aWidthScrubAsksForWidthsUnderOneToken() {
    let editor = rules()
    let first = scrub([2, 2.5, 3, 4, 6]) { editor.width($0, drag: $1) }
    #expect(first.count == 4) // the sample on the width already shown asks for nothing
    let tokens = Set(first.compactMap { intent -> String? in
        if case .width(_, let drag) = intent { return drag }
        return nil
    })
    #expect(tokens.count == 1)
    #expect(first.last.map { if case .width(6, _) = $0 { true } else { false } } == true)
    let second = scrub([7]) { editor.width($0, drag: $1) }
    if case .width(7, let drag) = second.first { #expect(drag != nil && !tokens.contains(drag ?? "")) } else {
        Issue.record("a second scrub asked for \(second)")
    }
    #expect(editor.width(5000, drag: nil) == .width(1000, drag: nil))
    #expect(editor.width(.nan, drag: nil) == nil)
}

@Test func roundJoinAsksForOneJoin() {
    #expect(rules().join(.round) == .join(.round))
    #expect(rules().join(.miter) == nil)
    #expect(rules().cap(.round) == .cap(.round))
    #expect(rules().cap(.butt) == nil)
}

@Test func dashedAsksForOneDashWithItsPreset() {
    #expect(rules().dash(.dashed) == .dash(.dashed, pattern: nil))
    #expect(rules().dash(.solid) == nil)
    #expect(rules().dash(.custom) == .dash(.custom, pattern: [8, 4]))
}

@Test func disabledRowsSayWhy() {
    let editor = rules(dashHelp: waiting)
    for row in [StrokeEditorRow.dash, .dashLength, .gap, .trimStart, .trimEnd, .trimOffset] {
        #expect(editor.reason(row) == waiting, "\(row) isn't disabled with dashHelp")
    }
    for row in [StrokeEditorRow.color, .width, .join, .cap, .remove] { #expect(editor.reason(row) == nil) }
    #expect(editor.dash(.dashed) == nil)
    #expect(editor.edit(.trimEnd, to: 40, drag: "d") == nil)
    #expect(editor.edit(.dashLength, to: 10, drag: nil) == nil)
    let locked = rules(help: "The layer is locked.", dashHelp: waiting)
    #expect(StrokeEditorRow.allCases.allSatisfy { locked.reason($0) == "The layer is locked." })
    #expect(locked.width(4, drag: nil) == nil && locked.join(.round) == nil)
    #expect(rules(nil).reason(.width) == StrokeEditorRules.noStroke)
}

@Test func trimRowsSendFractionsAndTurns() {
    #expect(rules().edit(.trimEnd, to: 40, drag: "d") == .trim(start: 0, end: 0.4, offset: 0, drag: "d"))
    #expect(rules().edit(.trimOffset, to: 90, drag: nil) == .trim(start: 0, end: 1, offset: 0.25, drag: nil))
    #expect(rules().edit(.trimStart, to: 0, drag: nil) == nil)
}

@Test func showsTrimFalseHidesTheTrimRows() {
    let rows = rules(showsTrim: false).rows
    #expect(rows == [.color, .width, .join, .cap, .dash, .remove])
    #expect(rules().rows == [.color, .width, .join, .cap, .dash, .trimStart, .trimEnd, .trimOffset, .remove])
    #expect(rules(nil).rows == [.add])
    #expect(rules(nil).reason(.add) == nil)
}

@Test func colorKeepsTheStrokesOpacity() {
    let editor = rules(VectorStroke(color: FillColor(r: 0, g: 0, b: 0, a: 0.5), width: 2))
    #expect(editor.color(HexColor(255, 0, 0), drag: "d") == .color(FillColor(r: 1, g: 0, b: 0, a: 0.5), drag: "d"))
    #expect(editor.color(.black, drag: nil) == nil)
    #expect(StrokeEditorRow.allCases.map(\.identifier).contains("suite.stroke.trim-offset"))
}

@Test func joinAndCapOptionsSayWhatTheyDraw() {
    for join in StrokeJoin.allCases {
        let line = StrokeEditorRules.help(join: join)
        #expect(line.hasPrefix(join.rawValue.capitalized + ": ") && line.count > join.rawValue.count + 4, "\(join)")
        #expect(rules().chipsHelp(.join).contains(line))
    }
    for cap in StrokeCap.allCases {
        let line = StrokeEditorRules.help(cap: cap)
        #expect(line.hasPrefix(cap.rawValue.capitalized + ": ") && line.count > cap.rawValue.count + 4, "\(cap)")
        #expect(rules().chipsHelp(.cap).contains(line))
    }
    #expect(StrokeEditorRules.help(join: .miter) == "Miter: sharp, pointed corners.")
    #expect(StrokeEditorRules.help(cap: .butt) == "Butt: the line ends exactly at its endpoint.")
    #expect(rules(help: "The layer is locked.").chipsHelp(.join) == "The layer is locked.")
    #expect(rules(nil).chipsHelp(.cap) == StrokeEditorRules.noStroke)
}

@Test func widthReadsInWholeOrHalfPoints() {
    #expect(StrokeEditorText.decimals(4) == 0 && StrokeEditorText.decimals(0.5) == 1)
    #expect(NumericInput.text(4, decimals: StrokeEditorText.decimals(4), unit: "pt") == "4 pt")
    #expect(NumericInput.text(0.5, decimals: StrokeEditorText.decimals(0.5), unit: "pt") == "0.5 pt")
    #expect(StrokeEditorText.points(4) == "4 pt" && StrokeEditorText.points(0.5) == "0.5 pt")
}

/// #3865: an app whose stroke can't hold a join or cap yet disables those chips with its reason, as a note too.
@Test func styleHelpDisablesJoinAndCap() {
    let why = "Design's strokes keep the default join and cap for now."
    let editor = StrokeEditorRules(stroke: VectorStroke(width: 2), help: nil, dashHelp: nil, showsTrim: false, styleHelp: why)
    #expect(editor.reason(.join) == why && editor.reason(.cap) == why && editor.chipsHelp(.cap) == why)
    #expect(editor.join(.round) == nil && editor.cap(.square) == nil)
    for row in [StrokeEditorRow.color, .width, .dash, .remove] { #expect(editor.reason(row) == nil, "\(row)") }
    #expect(editor.styleNote == why)
    let locked = StrokeEditorRules(stroke: VectorStroke(width: 2), help: "Locked.", dashHelp: nil, showsTrim: false, styleHelp: why)
    #expect(locked.reason(.join) == "Locked." && locked.styleNote == nil)
    #expect(StrokeEditorRules(stroke: nil, help: nil, dashHelp: nil, showsTrim: false, styleHelp: why).styleNote == nil)
    #expect(rules().styleNote == nil && rules().reason(.join) == nil)
}
