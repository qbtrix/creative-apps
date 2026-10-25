// DesignToolsKeyTests.swift: adopt-suiteui-chrome AC-tools. Design's canvas picks a tool from a typed letter
// through SuiteUI's ToolKeys, keeping Design's bindings: V F R O T in either case; never a tool the palette shows
// disabled (Shape, Pen); nothing for an unknown letter or more than one character. macOS only.
import DesignModel
import SuiteUI
import Testing

@testable import DesignApp

@Suite struct DesignToolsKeyTests {
    @Test func letterPicksTool() {
        let keys: [(String, DesignTool)] = [
            ("v", .move), ("f", .frame), ("r", .rectangle), ("o", .ellipse), ("t", .text),
        ]
        for (typed, tool) in keys {
            #expect(DesignTool.picked(byTyped: typed) == tool)
            #expect(DesignTool.picked(byTyped: typed.uppercased()) == tool)
        }
        #expect(DesignTool.picked(byTyped: "x") == nil)
        #expect(DesignTool.picked(byTyped: "") == nil)
        #expect(DesignTool.picked(byTyped: "rv") == nil)
    }

    @Test func disabledToolIsNotPicked() {
        for tool in DesignTool.allCases where !tool.isEnabled {
            let letter = tool.shortcut.map(String.init) ?? ""
            #expect(DesignTool.picked(byTyped: letter) == nil, "\(letter) picked a disabled tool")
            #expect(DesignTool.picked(byTyped: letter.uppercased()) == nil, "\(letter) picked a disabled tool")
        }
        #expect(DesignTool.allCases.contains { !$0.isEnabled })
    }
}
