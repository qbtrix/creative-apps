// SnapGuideMarksTests.swift: where SnapGuideMarks pins each gap's length pill.
// A gap long enough on screen to hold its pill plus a handle carries the pill
// on its middle; a shorter one hangs it beside the gap line, clear of the end
// ticks and the selection handle it would cover (the Mac finish pass of the
// smart guides: a 28-point gap at 50% put its pill over the top handle). Each
// alignment line ends in a small cross at both ends, one size at any zoom.
// macOS only.
import CoreGraphics
import SuiteKernel
import SuiteUI
import Testing

@Test func aLongGapCarriesItsPillOnItsMiddle() {
    let guides = SnapGuides(gaps: [
        SnapGap(axis: .y, from: 72, to: 100, across: 150, isSpacing: false),
        SnapGap(axis: .x, from: 200, to: 300, across: 150, isSpacing: false),
    ])
    let labels = SnapGuideMarks.labels(guides, zoom: 2)
    #expect(labels.map(\.side) == [.on, .on])
    #expect(labels.map(\.at) == [CGPoint(x: 300, y: 172), CGPoint(x: 500, y: 300)])
}

@Test func aShortVerticalGapHangsItsPillBesideTheLine() {
    let gap = SnapGap(axis: .y, from: 72, to: 100, across: 150, isSpacing: false)
    let label = SnapGuideMarks.labels(SnapGuides(gaps: [gap]), zoom: 0.5).first
    #expect(label?.side == .trailing)
    #expect(label?.at == CGPoint(x: 75 + SuiteSize.selectionHandle / 2 + SuiteSpacing.xs, y: 43))
}

@Test func aShortHorizontalGapHangsItsPillUnderTheLine() {
    let gap = SnapGap(axis: .x, from: 200, to: 210, across: 150, isSpacing: true)
    let label = SnapGuideMarks.labels(SnapGuides(gaps: [gap]), zoom: 1).first
    #expect(label?.side == .below)
    #expect(label?.at == CGPoint(x: 205, y: 150 + SuiteSize.selectionHandle / 2 + SuiteSpacing.xs))
}

@Test func anAlignmentLineEndsInACrossOneSizeAtAnyZoom() {
    let guides = SnapGuides(lines: [SnapLine(axis: .x, at: 300, from: 100, to: 220)])
    let arm = SuiteSize.anchor / 2
    for zoom in [0.5, 2.0] {
        let box = SnapGuideMarks.crosses(guides, zoom: zoom).boundingRect
        let x = 300 * zoom, top = 100 * zoom, bottom = 220 * zoom
        #expect(box == CGRect(x: x - arm, y: top - arm, width: 2 * arm, height: bottom - top + 2 * arm))
    }
    #expect(SnapGuideMarks.crosses(SnapGuides(lines: [SnapLine(axis: .y, at: .nan, from: 0, to: 1)]), zoom: 1).isEmpty)
}
