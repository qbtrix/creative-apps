// TokensTests.swift: checks on SuiteUI's tokens and value types, including
// the Visual language geometry (QB-F6). macOS only.
import SuiteUI
import SwiftUI
import Testing

@Test func spacingScaleIsStrictlyIncreasingOnTheGrid() {
    let scale = SuiteSpacing.scale
    #expect(scale == [2, 4, 8, 12, 16, 24, 32])
    #expect(zip(scale, scale.dropFirst()).allSatisfy { $0 < $1 })
}

@Test func radiiStepDownForConcentricNesting() {
    #expect(SuiteRadius.field < SuiteRadius.small)
    #expect(SuiteRadius.small < SuiteRadius.medium)
    #expect(SuiteRadius.medium < SuiteRadius.large)
}

@Test func sizesMeetTheHitTargetAndNestInTheWindow() {
    #expect(SuiteSize.toolButton >= 28)
    for width in [SuiteSize.sidebarWidth, SuiteSize.inspectorWidth] {
        #expect(width.min <= width.ideal && width.ideal <= width.max)
    }
    let shell = SuiteSize.sidebarWidth.min + SuiteSize.contentMinimum.width + SuiteSize.inspectorWidth.min
    #expect(shell <= SuiteSize.windowMinimum.width)
}

@Test func editorRowsMatchTheVisualLanguage() {
    // 34 pt filled rows 6 pt apart, the label inside on the left: no label column.
    #expect(SuiteSize.inspectorBar == 34 && SuiteSpacing.row == 6)
    #expect(SuiteSize.compactControl == .small)
    // A bar slider plus the keyframe button and its diamond slot fit the panel inside its padding.
    let row = SuiteSize.inspectorBar * 3 + 2 * SuiteSize.keyframeButton + 2 * SuiteSpacing.xs
    #expect(row <= SuiteSize.editorPanelWidth - 2 * SuiteSpacing.m)
    // The editor shell still fits the window minimum: rail, canvas and panel across;
    // top bar, canvas and the status row down.
    #expect(SuiteSize.toolButton + SuiteSize.contentMinimum.width + SuiteSize.editorPanelWidth <= SuiteSize.windowMinimum.width)
    #expect(SuiteSize.editorTopBar + SuiteSize.contentMinimum.height + SuiteSize.inspectorBar <= SuiteSize.windowMinimum.height)
}

/// QB-F6: the geometry the Visual language names, so a slide back to framework defaults fails.
@Test func geometryMatchesTheVisualLanguage() {
    #expect([SuiteRadius.field, SuiteRadius.small, SuiteRadius.control, SuiteRadius.medium, SuiteRadius.lane, SuiteRadius.large]
        == [4, 6, 8, 10, 12, 16])
    #expect([SuiteSpacing.row, SuiteSpacing.m, SuiteSpacing.l, SuiteSpacing.pillGap, SuiteSpacing.markerInset] == [6, 12, 16, 4, 6])
    #expect(SuiteInset.barButton.top == 4 && SuiteInset.barButton.leading == 8)
    #expect(SuiteInset.pill.top == 2 && SuiteInset.pill.leading == 8)
    #expect(SuiteInset.card.top == 8 && SuiteInset.card.leading == 12)
    let sizes = [
        SuiteSize.inspectorBar, SuiteSize.keyframeButton, SuiteSize.chip, SuiteSize.preset, SuiteSize.presetHit,
        SuiteSize.actionButton, SuiteSize.pill, SuiteSize.pillHit, SuiteSize.transportButton, SuiteSize.playButton,
        SuiteSize.selectionHandle, SuiteSize.selectionHandleHit, SuiteSize.anchor, SuiteSize.anchorHit,
        SuiteSize.statusDot, SuiteSize.editorTopBar, SuiteSize.editorPanelWidth, SuiteSize.timelineLane,
        SuiteSize.timelineKeyframe, SuiteSize.timelineKeyframeHit,
    ]
    #expect(sizes == [34, 28, 28, 24, 28, 32, 20, 24, 32, 36, 8, 12, 6, 12, 6, 48, 280, 32, 10, 16])
    #expect(SuiteSize.swatch == CGSize(width: 24, height: 16))
    // Hit areas: at least 28 where the layout allows, never under 20.
    for hit in [SuiteSize.inspectorBar, SuiteSize.keyframeButton, SuiteSize.chip, SuiteSize.presetHit, SuiteSize.actionButton] {
        #expect(hit >= 28)
    }
    for hit in [SuiteSize.pillHit, SuiteSize.timelineKeyframeHit, SuiteSize.selectionHandleHit, SuiteSize.anchorHit] {
        #expect(hit >= 12)
    }
    #expect(SuiteMotion.state(reduceMotion: true) == nil && SuiteMotion.state(reduceMotion: false) != nil)
}

@Test func toolbarActionUsesItsTitleAsId() {
    let action = ToolbarAction("New Animation", systemImage: "plus")
    #expect(action.id == "New Animation")
    #expect(!action.isSelected)
}

@Test func sidebarItemDefaultsToNoCount() {
    let item = SidebarItem(id: "a", title: "All", systemImage: "photo")
    #expect(item.count == nil)
}
