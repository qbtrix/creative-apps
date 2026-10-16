// ToolWellTests.swift: what a ToolbarGroup tool button's well shows under the
// pointer (ToolWell.state). Selected wins; then pressed, then hover; a
// disabled tool shows nothing, since it can't act. No SwiftUI rendering.
// macOS only.
import Testing

@testable import SuiteUI

@Test func toolWellShowsHoverAndPressOnAnIdleTool() {
    #expect(ToolWell.state(isSelected: false, isEnabled: true, isHovering: false, isPressed: false) == .clear)
    #expect(ToolWell.state(isSelected: false, isEnabled: true, isHovering: true, isPressed: false) == .hovered)
    #expect(ToolWell.state(isSelected: false, isEnabled: true, isHovering: true, isPressed: true) == .pressed)
}

@Test func toolWellKeepsTheSelectedTintUnderThePointer() {
    #expect(ToolWell.state(isSelected: true, isEnabled: true, isHovering: true, isPressed: true) == .selected)
}

@Test func toolWellStaysClearOnADisabledTool() {
    #expect(ToolWell.state(isSelected: true, isEnabled: false, isHovering: true, isPressed: true) == .clear)
}
