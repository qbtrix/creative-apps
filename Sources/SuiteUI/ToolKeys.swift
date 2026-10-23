// ToolKeys.swift: the one home of an editor's tool keys (EK-31). `tool(forKey:in:)`
// picks the enabled PaletteTool whose one-key shortcut is `key`, in either
// case, through SuiteToolPicking's rule (UC6), so a canvas and the floating
// palette pick the same tool for a key. `KeyModifiers(flags:)` and
// `KeyModifiers(nsEvent:)` are the one map from AppKit's modifier flags to the
// contracts' KeyModifiers: Shift, Option and Command; the rest are dropped.
// TimelineLaneInput reads its press modifiers through it.
import AppKit

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
