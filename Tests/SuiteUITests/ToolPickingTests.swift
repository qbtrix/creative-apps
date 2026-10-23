// ToolPickingTests.swift: SuiteToolPicking, the floating palette's live rule
// (EC-8b). A key picks only an enabled tool, in either case; help is
// "Title (K)", the title alone or the reason; a blank reason and a shortcut
// used twice are violations, sorted. No SwiftUI. macOS only.
import SuiteUI
import Testing

private let rule = SuiteToolPicking()
private let palette = [
    ToolFace(id: "tool.eraser", title: "Eraser", shortcut: "b", unavailableHelp: "Open a layer to erase."),
    ToolFace(id: "tool.brush", title: "Brush", shortcut: "b"),
    ToolFace(id: "tool.hand", title: "Hand"),
]

@Test func aKeyPicksTheEnabledToolInEitherCase() {
    #expect(rule.tool(forKey: "b", in: palette) == "tool.brush")
    #expect(rule.tool(forKey: "B", in: palette) == "tool.brush")
    #expect(rule.tool(forKey: "h", in: palette) == nil)
}

@Test func aKeyNeverPicksADisabledTool() {
    let onlyDisabled = [palette[0], palette[2]]
    #expect(rule.tool(forKey: "b", in: onlyDisabled) == nil)
    #expect(rule.tool(forKey: "B", in: onlyDisabled) == nil)
}

@Test func helpIsTheTitleWithItsKeyTheTitleAloneOrTheReason() {
    #expect(rule.help(for: palette[1]) == "Brush (B)")
    #expect(rule.help(for: palette[2]) == "Hand")
    #expect(rule.help(for: palette[0]) == "Open a layer to erase.")
}

@Test func aSharedKeyAndABlankReasonAreViolationsSorted() {
    let tools = [
        ToolFace(id: "tool.pen", title: "Pen", shortcut: "p"),
        ToolFace(id: "tool.brush", title: "Brush", shortcut: "B"),
        ToolFace(id: "tool.blur", title: "Blur", shortcut: "b"),
        ToolFace(id: "tool.crop", title: "Crop", unavailableHelp: ""),
        ToolFace(id: "tool.fill", title: "Fill", unavailableHelp: "  "),
    ]
    #expect(rule.violations(in: tools) == ["tool.blur", "tool.brush", "tool.crop", "tool.fill"])
}

@Test func aCleanPaletteHasNoViolations() {
    #expect(rule.violations(in: [palette[1], palette[2]]).isEmpty)
    #expect(rule.violations(in: []).isEmpty)
}

@Test func aToolBreakingBothRulesIsListedOnce() {
    let tools = [
        ToolFace(id: "tool.a", title: "A", shortcut: "a", unavailableHelp: ""),
        ToolFace(id: "tool.b", title: "B", shortcut: "A"),
    ]
    #expect(rule.violations(in: tools) == ["tool.a", "tool.b"])
}
