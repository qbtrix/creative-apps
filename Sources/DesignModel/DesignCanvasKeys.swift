// DesignCanvasKeys.swift: what a key pressed on the canvas does (#2706). Arrows
// nudge the selection (Shift: ten points), Delete removes it, Escape deselects and
// Return edits a selected text node; nil leaves the key to the system (the canvas
// then pans on an arrow). "The selection" is every selected layer: with several,
// nudge and delete go through `run` (DesignCanvasEditing). Command, Option or
// Control held leaves every key to the menus. The keyboard's own flags never stop
// a key: macOS marks every arrow press as a numeric-pad key, and Caps Lock may be
// on. Linux-safe.

/// A key the canvas acts on.
public enum DesignCanvasKey: Hashable, Sendable {
    case arrow(DesignDirection)
    case delete, escape, enter
}

/// The flags held with a key press, as the canvas reads them.
public struct DesignKeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = DesignKeyModifiers(rawValue: 1)
    public static let command = DesignKeyModifiers(rawValue: 2)
    public static let option = DesignKeyModifiers(rawValue: 4)
    public static let control = DesignKeyModifiers(rawValue: 8)
    /// Set on every arrow press as well as the keypad's keys.
    public static let numericPad = DesignKeyModifiers(rawValue: 16)
    public static let capsLock = DesignKeyModifiers(rawValue: 32)

    /// No Command, Option or Control: the canvas, not a menu, takes the key.
    public var reachesCanvas: Bool { isDisjoint(with: [.command, .option, .control]) }
}

/// What a canvas key does to the workspace.
public enum DesignCanvasKeyAction: Hashable, Sendable {
    case nudge(DesignDirection, shift: Bool)
    case deleteSelection, deselect
    case editText(String)
}

extension DesignWorkspace {
    /// At least one layer is selected.
    public var hasSelection: Bool { !selectedNodeIDs.isEmpty }

    /// What `key` with `modifiers` does on the canvas; nil leaves it to the system.
    public func canvasKeyAction(_ key: DesignCanvasKey, modifiers: DesignKeyModifiers) -> DesignCanvasKeyAction? {
        guard modifiers.reachesCanvas else { return nil }
        switch key {
        case .arrow(let direction): return hasSelection ? .nudge(direction, shift: modifiers.contains(.shift)) : nil
        case .delete: return hasSelection ? .deleteSelection : nil
        case .escape: return .deselect
        case .enter:
            guard let node = selectedNode, node.kind == .text else { return nil }
            return .editText(node.id)
        }
    }
}
