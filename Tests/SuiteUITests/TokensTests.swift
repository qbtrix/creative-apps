// TokensTests.swift: checks on SuiteUI's tokens and value types. macOS only.
import SuiteUI
import Testing

@Test func spacingScaleIsStrictlyIncreasingOnTheGrid() {
    let scale = SuiteSpacing.scale
    #expect(scale == [2, 4, 8, 12, 16, 24, 32])
    #expect(zip(scale, scale.dropFirst()).allSatisfy { $0 < $1 })
}

@Test func radiiStepDownForConcentricNesting() {
    #expect(SuiteRadius.small < SuiteRadius.medium)
    #expect(SuiteRadius.medium < SuiteRadius.large)
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
