// TokensTests.swift: checks on SuiteUI's tokens and value types. macOS only.
import SuiteUI
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

@Test func proDensityRowsAreTightAndFitTheInspector() {
    #expect((20...22).contains(SuiteSize.inspectorRow))
    #expect(SuiteSize.compactControl == .small)
    // Label column, gap and a field still fit the narrowest inspector inside its inset.
    let row = SuiteSize.inspectorLabelColumn + SuiteSpacing.s + SuiteSize.inspectorField
    #expect(row <= SuiteSize.inspectorWidth.min - 2 * SuiteSpacing.m)
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
