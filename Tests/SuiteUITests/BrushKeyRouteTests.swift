// BrushKeyRouteTests.swift (brush-keys BK-5): ToolKeys.brushAction hands key events to BrushKeys' rule, passes
// Command and Option keys on and does nothing while a text input has the keys; BrushKeyReadout names each action.
import AppKit
import SuiteKernel
import SuiteUI
import Testing

@MainActor @Suite struct BrushKeyRouteTests {
    @Test func bracketStepsSizeThroughTheKernelRule() throws {
        var digits = OpacityDigits()
        #expect(try Self.act("]", settings: BrushSettings(), digits: &digits) == .brush(.size(25)))
        #expect(try Self.act("[", settings: BrushSettings(size: 10), digits: &digits) == .brush(.size(9)))
    }

    @Test func shiftIsRead() throws {
        var digits = OpacityDigits()
        let settings = BrushSettings(hardness: 50)
        // AppKit reports Shift-] as "}" ignoring modifiers on most layouts; both read as Shift.
        #expect(try Self.act("]", flags: .shift, settings: settings, digits: &digits) == .brush(.hardness(75)))
        #expect(try Self.act("}", flags: .shift, settings: settings, digits: &digits) == .brush(.hardness(75)))
        #expect(try Self.act("5", flags: .shift, settings: settings, digits: &digits) == nil)
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

    @Test func commandAndOptionGoOn() throws {
        var digits = OpacityDigits()
        #expect(try Self.act("]", settings: nil, digits: &digits) == nil)
        #expect(try Self.act("]", flags: .command, settings: BrushSettings(), digits: &digits) == nil)
        #expect(try Self.act("5", flags: .option, settings: BrushSettings(), digits: &digits) == nil)
        #expect(try Self.act("]", type: .keyUp, settings: BrushSettings(), digits: &digits) == nil)
    }

    @Test func fieldKeepsDigits() throws {
        var digits = OpacityDigits()
        let field = NSTextView()
        #expect(ToolKeys.isTextInput(field))
        #expect(try Self.act("9", firstResponder: field, settings: BrushSettings(), digits: &digits) == nil)
        #expect(try Self.act("]", firstResponder: field, settings: BrushSettings(), digits: &digits) == nil)
        let editable = NSTextField()
        editable.isEditable = true
        #expect(ToolKeys.isTextInput(editable))
        #expect(!ToolKeys.isTextInput(NSTextField(labelWithString: "Size")))
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
