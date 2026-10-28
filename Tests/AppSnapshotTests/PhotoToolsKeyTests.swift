// PhotoToolsKeyTests.swift: adopt-suiteui-chrome AC-tools. Photo's editor picks a tool from a typed letter
// through SuiteUI's ToolKeys over its PhotoPaletteTool faces, keeping Photo's bindings: V M B E S J C I G in either
// case; never a tool the workspace's help disables; nothing for an unknown letter or more than one character. A
// shared letter picks its first enabled tool (fill-heal FH-3: J Spot Heal, G Paint Bucket), Heal and Gradient while
// the retouch tools wait, and Shift cycles the letter's enabled tools. macOS only.
import PhotoModel
import SuiteUI
import Testing

@testable import PhotoApp

@Suite struct PhotoToolsKeyTests {
    private let open: (PhotoTool) -> String? = { _ in nil }

    @Test func letterPicksTool() {
        let keys: [(String, PhotoTool)] = [
            ("v", .move), ("m", .marquee), ("b", .brush), ("e", .eraser), ("s", .clone), ("j", .spotHeal),
            ("c", .crop), ("i", .eyedropper), ("g", .bucket),
        ]
        for (typed, tool) in keys {
            #expect(PhotoTool.picked(byTyped: typed, help: open) == tool)
            #expect(PhotoTool.picked(byTyped: typed.uppercased(), help: open) == tool)
        }
        #expect(PhotoTool.picked(byTyped: "x", help: open) == nil)
        #expect(PhotoTool.picked(byTyped: "", help: open) == nil)
        #expect(PhotoTool.picked(byTyped: "bv", help: open) == nil)
    }

    @Test func sharedLetterPicksHealAndGradientWhileRetouchWaits() {
        let retouchWaits: (PhotoTool) -> String? = { $0.unavailableHelp == PhotoTool.retouchHelp ? $0.unavailableHelp : nil }
        #expect(PhotoTool.picked(byTyped: "j", help: retouchWaits) == .heal)
        #expect(PhotoTool.picked(byTyped: "J", help: retouchWaits) == .heal)
        #expect(PhotoTool.picked(byTyped: "g", help: retouchWaits) == .gradient)
        #expect(PhotoTool.picked(byTyped: "J", help: retouchWaits, cyclingFrom: .heal) == .heal)
        #expect(PhotoTool.picked(byTyped: "G", help: retouchWaits, cyclingFrom: .gradient) == .gradient)
    }

    @Test func shiftLetterCyclesTheGroup() {
        let shiftJ: [(PhotoTool, PhotoTool)] = [(.move, .spotHeal), (.spotHeal, .heal), (.heal, .remove), (.remove, .spotHeal)]
        for (from, to) in shiftJ {
            #expect(PhotoTool.picked(byTyped: "J", help: open, cyclingFrom: from) == to)
        }
        #expect(PhotoTool.picked(byTyped: "G", help: open, cyclingFrom: .brush) == .bucket)
        #expect(PhotoTool.picked(byTyped: "G", help: open, cyclingFrom: .bucket) == .gradient)
        #expect(PhotoTool.picked(byTyped: "G", help: open, cyclingFrom: .gradient) == .bucket)
        // A lone letter stays on its tool; a disabled tool in the group is stepped over.
        #expect(PhotoTool.picked(byTyped: "B", help: open, cyclingFrom: .brush) == .brush)
        let noHeal: (PhotoTool) -> String? = { $0 == .heal ? "Open an image to heal it." : nil }
        #expect(PhotoTool.picked(byTyped: "J", help: noHeal, cyclingFrom: .spotHeal) == .remove)
    }

    @Test func disabledToolIsNotPicked() {
        let noImage: (PhotoTool) -> String? = { $0 == .brush ? "Open an image to paint on it." : nil }
        #expect(PhotoTool.picked(byTyped: "b", help: noImage) == nil)
        #expect(PhotoTool.picked(byTyped: "B", help: noImage) == nil)
        #expect(PhotoTool.picked(byTyped: "e", help: noImage) == .eraser)
    }
}
