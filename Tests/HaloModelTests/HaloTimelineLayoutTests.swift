// HaloTimelineLayoutTests.swift: the timeline strip's geometry. At window
// widths 600, 880 and 1440 the fitted lanes, the name column, the divider and
// the trailing room fit the width (so no sideways scroller covers the ruler),
// and the height stays within 40% of what is available, at least the slot
// minimum when there is room, and never negative. Runs on Linux and macOS.
@testable import HaloModel
import Testing

/// SuiteUI's tokens: timelineLabelColumn, the Divider, SuiteSpacing.xl,
/// timelineRuler, timelineLane and timelineSlotMinimum.
private let layout = HaloTimelineLayout(
    labelColumn: 160, divider: 1, trailingRoom: 24, ruler: 24, lane: 32, minimumHeight: 120)

@Test(arguments: [600.0, 880.0, 1440.0])
func lanesFitTheStripWidth(width: Double) throws {
    let lanes = layout.laneFitWidth(width: width)
    #expect(lanes > 0)
    #expect(lanes + layout.labelColumn + layout.divider + layout.trailingRoom <= width)
    for fps in [24, 30] {
        var project = HaloProject()
        project.newComposition(CompositionSettings(name: "Comp", framesPerSecond: fps, durationSeconds: 10))
        let comp = try #require(project.selectedComposition)
        let content = Double(comp.lastFrame) * comp.frameWidth(toFit: lanes) + layout.trailingRoom
        #expect(content <= width - layout.labelColumn - layout.divider + 1e-9)
    }
}

/// #1019: the lanes fit the width the strip shows at, not its container's,
/// which counted 168 pt under the inspector at 880: lanes plus the name
/// column, divider and trailing room add up to exactly the visible width.
@Test(arguments: [(463.0, 295.0), (556.0, 499.0), (643.0, 643.0)])
func lanesFitTheVisibleStripWidth(container: Double, visible: Double) {
    let lanes = layout.laneFitWidth(strip: visible, container: container)
    #expect(lanes + layout.labelColumn + layout.divider + layout.trailingRoom == visible)
    #expect(lanes <= layout.laneFitWidth(width: container))
}

/// Before the strip is measured (or when the measure is nonsense) the
/// container's width is all there is.
@Test func anUnmeasuredStripFitsTheContainer() {
    for strip in [nil, 0, -20, .nan, .infinity] as [Double?] {
        #expect(layout.laneFitWidth(strip: strip, container: 880) == layout.laneFitWidth(width: 880))
    }
}

@Test func laneWidthIsNeverNegative() {
    #expect(layout.laneFitWidth(width: 0) == 0)
    #expect(layout.laneFitWidth(width: 100) == 0)
    #expect(layout.laneFitWidth(width: -50) == 0)
    #expect(layout.laneFitWidth(width: .infinity) == 0)
}

@Test(arguments: [0, 1, 2, 10, 100])
func heightIsCappedAndKeepsTheMinimum(rows: Int) {
    for available in [300.0, 500.0, 612.0, 640.0, 1200.0] {
        let height = layout.height(rows: rows, available: available)
        #expect(height >= 0)
        #expect(height <= available * 0.4)
        if available * 0.4 >= layout.minimumHeight {
            #expect(height >= layout.minimumHeight)
        }
    }
}

@Test func heightFollowsTheLanesUntilTheCap() {
    #expect(layout.height(rows: 2, available: 1200) == 120)
    #expect(layout.height(rows: 6, available: 1200) == 24 + 32 * 6)
    #expect(layout.height(rows: 100, available: 1200) == 480)
    #expect(layout.height(rows: 10, available: 640) == 256)
}

@Test func anEmptyTimelineKeepsALaneForItsHint() {
    #expect(layout.contentHeight(rows: 0) == 24 + 32)
    #expect(layout.contentHeight(rows: -3) == 24 + 32)
}

@Test func degenerateAvailableHeightGivesZero() {
    #expect(layout.height(rows: 3, available: 0) == 0)
    #expect(layout.height(rows: 3, available: -10) == 0)
    #expect(layout.height(rows: 3, available: .nan) == 0)
    #expect(layout.height(rows: 3, available: 200) == 80)
}

/// B4: a click below the ruler and right of the names lands in a lane; the
/// ruler, the names column and the space under the last lane are no lane.
@Test func aClickInTheLanesFindsItsRow() {
    let lanes = 160.0 + 1 + 0.5
    #expect(layout.row(atX: lanes, y: 24, rows: 3) == 0)
    #expect(layout.row(atX: lanes, y: 55.9, rows: 3) == 0)
    #expect(layout.row(atX: 600, y: 56, rows: 3) == 1)
    #expect(layout.row(atX: 600, y: 119.9, rows: 3) == 2)
    #expect(layout.row(atX: 600, y: 120, rows: 3) == nil)
    #expect(layout.row(atX: 600, y: 23.9, rows: 3) == nil)
    #expect(layout.row(atX: 161, y: 40, rows: 3) == nil)
    #expect(layout.row(atX: 600, y: 40, rows: 0) == nil)
    #expect(layout.row(atX: .nan, y: 40, rows: 3) == nil)
    #expect(layout.row(atX: 600, y: .nan, rows: 3) == nil)
}
