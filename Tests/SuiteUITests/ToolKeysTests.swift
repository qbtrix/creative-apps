// ToolKeysTests.swift: ToolKeys (EK-31). A letter picks the enabled
// PaletteTool on that shortcut, in either case, never a disabled one, and
// nothing when no tool has it; Shift steps through the enabled tools sharing a
// letter, wrapping; KeyModifiers from AppKit's flags keeps Shift,
// Option and Command and drops the rest. macOS only.
import AppKit
import SuiteUI
import Testing

private enum KeyTool: String, PaletteTool, CaseIterable {
    case move, brush, eraser, hand
    var title: String { rawValue.capitalized }
    var systemImage: String { "circle" }
    var gesture: ToolGesture { .none }
    var unavailableHelp: String? { self == .eraser ? "Open a layer to erase." : nil }
    var shortcut: Character? {
        switch self {
        case .move: "v"
        case .brush: "b"
        case .eraser: "e"
        case .hand: nil
        }
    }
}

@Suite struct ToolKeysTests {
    @Test func letterPicksTool() {
        let all = KeyTool.allCases
        #expect(ToolKeys.tool(forKey: "b", in: all) == .brush)
        #expect(ToolKeys.tool(forKey: "B", in: all) == .brush)
        #expect(ToolKeys.tool(forKey: "V", in: all) == .move)
        // B picks nothing when no tool has B.
        #expect(ToolKeys.tool(forKey: "B", in: [KeyTool.move, .hand]) == nil)
        // A disabled tool's letter picks nothing; an unknown letter neither.
        #expect(ToolKeys.tool(forKey: "e", in: all) == nil)
        #expect(ToolKeys.tool(forKey: "x", in: all) == nil)
        #expect(ToolKeys.tool(forKey: "b", in: [KeyTool]()) == nil)
    }

    @Test func shiftCyclesASharedLetter() {
        let faces = ["a", "b", "c", "d"].map { ToolFace(id: $0, title: $0, shortcut: $0 == "d" ? "x" : "j") }
        #expect(ToolKeys.id(forKey: "j", in: faces) == "a")
        #expect(ToolKeys.id(forKey: "J", in: faces, after: "a") == "b")
        #expect(ToolKeys.id(forKey: "J", in: faces, after: "c") == "a")
        #expect(ToolKeys.id(forKey: "J", in: faces, after: "d") == "a")
        var waiting = faces
        waiting[1].unavailableHelp = "Not yet."
        #expect(ToolKeys.id(forKey: "J", in: waiting, after: "a") == "c")
        #expect(ToolKeys.id(forKey: "x", in: faces, after: "d") == "d")
        #expect(ToolKeys.id(forKey: "q", in: faces, after: "a") == nil)
        let all = KeyTool.allCases
        #expect(ToolKeys.tool(forKey: "B", in: all, cyclingFrom: { $0 == .brush }) == .brush)
        #expect(ToolKeys.tool(forKey: "B", in: all, cyclingFrom: { $0 == .move }) == .brush)
    }

    @Test func modifiersFromFlags() {
        #expect(KeyModifiers(flags: [.shift]) == .shift)
        #expect(KeyModifiers(flags: [.option]) == .option)
        #expect(KeyModifiers(flags: [.command]) == .command)
        #expect(KeyModifiers(flags: [.shift, .command, .control, .capsLock]) == [.shift, .command])
        #expect(KeyModifiers(flags: []).isEmpty)
        #expect(KeyModifiers(flags: [.control, .function]).isEmpty)
    }

    @Test func modifiersFromAnEvent() throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.shift, .option], timestamp: 0, windowNumber: 0,
            context: nil, characters: "B", charactersIgnoringModifiers: "b", isARepeat: false, keyCode: 11))
        #expect(KeyModifiers(nsEvent: event) == [.shift, .option])
    }
}
