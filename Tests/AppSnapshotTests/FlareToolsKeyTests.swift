// FlareToolsKeyTests.swift: adopt-suiteui-chrome AC-tools. The stage picks a tool from a typed letter and reads
// Shift and Option through SuiteUI's ToolKeys and KeyModifiers, keeping Flare's bindings: V A R E P U in either
// case, never a tool its help disables, nothing for an unknown letter or more than one character; Command and
// Control never reach a drag. macOS only.
import AppKit
import FlareModel
import SuiteUI
import Testing

@testable import FlareApp

@Suite struct FlareToolsKeyTests {
    private let open: (FlareTool) -> String? = { _ in nil }

    @Test func letterPicksTool() {
        let keys: [(String, FlareTool)] = [
            ("v", .select), ("a", .directSelect), ("r", .rectangle), ("e", .ellipse), ("p", .pen), ("u", .shape),
        ]
        for (typed, tool) in keys {
            #expect(FlareTool.picked(byTyped: typed, help: open) == tool)
            #expect(FlareTool.picked(byTyped: typed.uppercased(), help: open) == tool)
        }
        #expect(FlareTool.picked(byTyped: "x", help: open) == nil)
        #expect(FlareTool.picked(byTyped: "", help: open) == nil)
        #expect(FlareTool.picked(byTyped: "rv", help: open) == nil)
    }

    @Test func disabledToolIsNotPicked() {
        let locked: (FlareTool) -> String? = { $0 == .pen ? "Unlock Layer 1 to draw on it." : nil }
        #expect(FlareTool.picked(byTyped: "p", help: locked) == nil)
        #expect(FlareTool.picked(byTyped: "r", help: locked) == .rectangle)
    }

    @Test func dragReadsShiftAndOption() {
        #expect(DragModifiers(KeyModifiers(flags: [.shift])) == .shift)
        #expect(DragModifiers(KeyModifiers(flags: [.option])) == .option)
        #expect(DragModifiers(KeyModifiers(flags: [.shift, .option, .command, .control])) == [.shift, .option])
        #expect(DragModifiers(KeyModifiers(flags: [.command, .capsLock])).isEmpty)
    }
}
