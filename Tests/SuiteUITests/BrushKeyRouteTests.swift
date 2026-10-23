// BrushKeyRouteTests.swift (brush-keys BK-5): ToolKeys.brushAction reads an AppKit key event through KeyModifiers
// and hands it to the kernel's BrushKeys rule: `]` steps the size up a band, Shift moves hardness, digits set
// opacity (two inside the window make an exact percent), Command and Option keys go on, and nothing happens while a
// text input is first responder, so a field keeps its digits. BrushKeyReadout's text names each action.
import AppKit
import SuiteKernel
import SuiteUI
import Testing

@MainActor @Suite struct BrushKeyRouteTests {
    @Test func bracketStepsSizeThroughTheKernelRule() throws {
        var digits = OpacityDigits()
        let up = try Self.act("]", settings: BrushSettings(), digits: &digits)
        #expect(up == .brush(.size(BrushKeys.step(size: 20, up: true))))
        #expect(up == .brush(.size(25)))
        let down = try Self.act("[", settings: BrushSettings(size: 10), digits: &digits)
        #expect(down == .brush(.size(9)))
    }

    @Test func shiftIsRead() throws {
        var digits = OpacityDigits()
        let settings = BrushSettings(hardness: 50)
        // AppKit reports Shift-] as "}" ignoring modifiers on most layouts; both read as Shift.
        let bracket = try Self.act("]", flags: .shift, settings: settings, digits: &digits)
        let brace = try Self.act("}", flags: .shift, settings: settings, digits: &digits)
        let digit = try Self.act("5", flags: .shift, settings: settings, digits: &digits)
        #expect(bracket == .brush(.hardness(75)))
        #expect(brace == .brush(.hardness(75)))
        #expect(digit == nil)
    }

    @Test func digitsSetOpacity() throws {
        var digits = OpacityDigits()
        let tens = try Self.act("5", at: 10, settings: BrushSettings(), digits: &digits)
        #expect(tens == .brush(.opacity(50)))
        var pair = OpacityDigits()
        _ = try Self.act("4", at: 20, settings: BrushSettings(), digits: &pair)
        let exact = try Self.act("5", at: 20.2, settings: BrushSettings(), digits: &pair)
        #expect(exact == .brush(.opacity(45)))
        var layers = OpacityDigits()
        let layer = try Self.act("0", at: 30, settings: nil, digits: &layers)
        #expect(layer == .layerOpacity(100))
    }

    @Test func bracketsNeedABrush() throws {
        var digits = OpacityDigits()
        let none = try Self.act("]", settings: nil, digits: &digits)
        #expect(none == nil)
    }

    @Test func commandAndOptionGoOn() throws {
        var digits = OpacityDigits()
        let command = try Self.act("]", flags: .command, settings: BrushSettings(), digits: &digits)
        let option = try Self.act("5", flags: .option, settings: BrushSettings(), digits: &digits)
        let up = try Self.act("]", type: .keyUp, settings: BrushSettings(), digits: &digits)
        #expect(command == nil)
        #expect(option == nil)
        #expect(up == nil)
    }

    @Test func fieldKeepsDigits() throws {
        var digits = OpacityDigits()
        let field = NSTextView()
        #expect(ToolKeys.isTextInput(field))
        let typed = try Self.act("9", firstResponder: field, settings: BrushSettings(), digits: &digits)
        let bracket = try Self.act("]", firstResponder: field, settings: BrushSettings(), digits: &digits)
        #expect(typed == nil)
        #expect(bracket == nil)
        let editable = NSTextField()
        editable.isEditable = true
        #expect(ToolKeys.isTextInput(editable))
        #expect(!ToolKeys.isTextInput(NSTextField(labelWithString: "Size")))
        #expect(!ToolKeys.isTextInput(NSView()))
        #expect(!ToolKeys.isTextInput(nil))
        // The digit the field kept never started a pair: the next digit on the canvas sets tens.
        let canvas = try Self.act("4", firstResponder: NSView(), settings: BrushSettings(), digits: &digits)
        #expect(canvas == .brush(.opacity(40)))
    }

    @Test func readoutTextForEachAction() {
        #expect(BrushKeyReadout.text(for: .brush(.size(25))) == "Size 25 px")
        #expect(BrushKeyReadout.text(for: .brush(.opacity(45))) == "Opacity 45%")
        #expect(BrushKeyReadout.text(for: .brush(.hardness(75))) == "Hardness 75%")
        #expect(BrushKeyReadout.text(for: .layerOpacity(100)) == "Layer opacity 100%")
        #expect(BrushKeyReadout.duration == 0.8)
    }

    /// ToolKeys.brushAction for a key event of `characters`; with `firstResponder`, read as that responder's key.
    static func act(
        _ characters: String, flags: NSEvent.ModifierFlags = [], type: NSEvent.EventType = .keyDown, at time: Double = 1,
        firstResponder: NSResponder? = nil, settings: BrushSettings?, digits: inout OpacityDigits
    ) throws -> BrushKeyAction? {
        let event = try #require(NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: flags, timestamp: time, windowNumber: 0, context: nil,
            characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: 0))
        guard let firstResponder else { return ToolKeys.brushAction(for: event, settings: settings, digits: &digits) }
        return ToolKeys.brushAction(for: event, firstResponder: firstResponder, settings: settings, digits: &digits)
    }
}
