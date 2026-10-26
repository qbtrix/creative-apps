// FocusedControlKeys.swift: who gets the plain step keys while a control has
// focus. A menu key equivalent fires before the focused view's onKeyPress, so
// an app menu that binds plain ←/→ (Flare's Animate > Next Frame) took the
// arrows from a focused inspector bar (#2487). While a ScrubField (its bar or
// its typing field) has focus it publishes FocusedValues.controlHasKeys, and a
// host's Commands pass each shortcut through `menuShortcut`, which drops the
// keys the field handles itself: the arrows with or without Shift or Option,
// Home, End and Space. ⌘ and ⌃ shortcuts always stay the menu's. With the
// canvas or the timeline focused nothing publishes it and the menu keeps them.
import SwiftUI

public enum FocusedControlKeys {
    /// The keys a focused ScrubField takes for itself.
    static let keys: [KeyEquivalent] = [.leftArrow, .rightArrow, .upArrow, .downArrow, .home, .end, .space]

    /// True when a focused control handles `shortcut` before the menu should.
    public static func takes(_ shortcut: KeyboardShortcut) -> Bool {
        shortcut.modifiers.isDisjoint(with: [.command, .control]) && keys.contains(shortcut.key)
    }

    /// `shortcut` for a menu item, or nil while a focused control has the keys and takes it.
    public static func menuShortcut(_ shortcut: KeyboardShortcut?, controlHasKeys: Bool?) -> KeyboardShortcut? {
        guard let shortcut, controlHasKeys == true, takes(shortcut) else { return shortcut }
        return nil
    }
}

/// A plain key rather than `@Entry`, so SuiteUI builds without the SwiftUI macro plugin.
private struct ControlHasKeysKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    /// True while a control that takes the step keys (ScrubField) has focus; nil otherwise.
    public var controlHasKeys: Bool? {
        get { self[ControlHasKeysKey.self] }
        set { self[ControlHasKeysKey.self] = newValue }
    }
}
