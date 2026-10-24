// PhotoToolsKeyTests.swift: adopt-suiteui-chrome AC-tools. Photo's editor picks a tool from a typed letter
// through SuiteUI's ToolKeys over its PhotoPaletteTool faces, keeping Photo's bindings: V M B E S J C I G in either
// case; never a tool the workspace's help disables; nothing for an unknown letter or more than one character.
// macOS only.
import PhotoModel
import SuiteUI
import Testing

@testable import PhotoApp

@Suite struct PhotoToolsKeyTests {
    private let open: (PhotoTool) -> String? = { _ in nil }

    @Test func letterPicksTool() {
        let keys: [(String, PhotoTool)] = [
            ("v", .move), ("m", .marquee), ("b", .brush), ("e", .eraser), ("s", .clone), ("j", .heal),
            ("c", .crop), ("i", .eyedropper), ("g", .gradient),
        ]
        for (typed, tool) in keys {
            #expect(PhotoTool.picked(byTyped: typed, help: open) == tool)
            #expect(PhotoTool.picked(byTyped: typed.uppercased(), help: open) == tool)
        }
        #expect(PhotoTool.picked(byTyped: "x", help: open) == nil)
        #expect(PhotoTool.picked(byTyped: "", help: open) == nil)
        #expect(PhotoTool.picked(byTyped: "bv", help: open) == nil)
    }

    @Test func disabledToolIsNotPicked() {
        let noImage: (PhotoTool) -> String? = { $0 == .brush ? "Open an image to paint on it." : nil }
        #expect(PhotoTool.picked(byTyped: "b", help: noImage) == nil)
        #expect(PhotoTool.picked(byTyped: "B", help: noImage) == nil)
        #expect(PhotoTool.picked(byTyped: "e", help: noImage) == .eraser)
    }
}
