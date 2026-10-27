// ToolKeys.swift: the one home of an editor's tool keys (EK-31). `tool(forKey:in:)`
// picks the enabled PaletteTool whose one-key shortcut is `key`, in either
// case, through SuiteToolPicking's rule (UC6), so a canvas and the floating
// palette pick the same tool for a key. `KeyModifiers(flags:)` and
// `KeyModifiers(nsEvent:)` are the one map from AppKit's modifier flags to the
// contracts' KeyModifiers: Shift, Option and Command; the rest are dropped.
// TimelineLaneInput reads its press modifiers through it.
// `brushAction` (brush-keys BK-5) routes a canvas's brush keys to the kernel's BrushKeys rule; ⌘ and ⌥ keys go on.
import AppKit
import SuiteKernel

public enum ToolKeys {
    /// The enabled tool in `tools` whose shortcut is `key` (case-insensitive); nil when none has it.
    public static func tool<Tool: PaletteTool>(
        forKey key: Character, in tools: [Tool], picking: some ToolPicking = SuiteToolPicking()
    ) -> Tool? {
        let faces = tools.enumerated().map { index, tool in
            ToolFace(id: String(index), title: tool.title, shortcut: tool.shortcut, unavailableHelp: tool.unavailableHelp)
        }
        guard let id = picking.tool(forKey: key, in: faces), let index = Int(id), tools.indices.contains(index)
        else { return nil }
        return tools[index]
    }

    /// The brush key `event` is, through BrushKeys' rule: nil for a key that isn't one, a key with Command or Option,
    /// or while the key window's first responder is a text input. `settings` is the active brush, nil for none.
    @MainActor public static func brushAction(
        for event: NSEvent, settings: BrushSettings?, digits: inout OpacityDigits
    ) -> BrushKeyAction? {
        let responder = event.window?.firstResponder ?? NSApplication.shared.keyWindow?.firstResponder
        return brushAction(for: event, firstResponder: responder, settings: settings, digits: &digits)
    }

    /// The brush key `event` is while `firstResponder` has the keys.
    @MainActor public static func brushAction(
        for event: NSEvent, firstResponder: NSResponder?, settings: BrushSettings?, digits: inout OpacityDigits
    ) -> BrushKeyAction? {
        guard event.type == .keyDown else { return nil }
        return brushAction(
            forKey: event.charactersIgnoringModifiers ?? "", modifiers: KeyModifiers(nsEvent: event), at: event.timestamp,
            firstResponder: firstResponder, settings: settings, digits: &digits)
    }

    /// The brush key `key` is with `modifiers` held at `time` (seconds), for a view with a key press but no event.
    @MainActor public static func brushAction(
        forKey key: String, modifiers: KeyModifiers, at time: Double, firstResponder: NSResponder?,
        settings: BrushSettings?, digits: inout OpacityDigits
    ) -> BrushKeyAction? {
        guard !isTextInput(firstResponder), modifiers.isDisjoint(with: [.command, .option]),
              key.count == 1, let character = key.first
        else { return nil }
        return BrushKeys.action(
            for: character, shift: modifiers.contains(.shift), settings: settings ?? BrushSettings(),
            brushActive: settings != nil, digits: &digits, now: time)
    }

    /// Whether `responder` takes typing: a text view (a field's editor among them) or an editable text field.
    @MainActor public static func isTextInput(_ responder: NSResponder?) -> Bool {
        if responder is NSText { return true }
        if let field = responder as? NSTextField { return field.isEditable }
        return false
    }
}

extension KeyModifiers {
    /// Shift, Option and Command from AppKit's flags; Control, Caps Lock and the rest are dropped.
    public init(flags: NSEvent.ModifierFlags) {
        self.init()
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.command) { insert(.command) }
    }

    /// The modifiers held during `event`.
    public init(nsEvent event: NSEvent) {
        self.init(flags: event.modifierFlags)
    }
}
