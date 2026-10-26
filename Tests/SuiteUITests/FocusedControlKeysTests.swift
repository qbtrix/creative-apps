// FocusedControlKeysTests.swift: the step keys go to a focused inspector bar,
// not the menu (#2487). With a bar focused, a menu's plain ←/→, ⌥←/⌥→, Home,
// End and Space shortcuts drop, so the bar steps; with the canvas or timeline
// focused (nothing published) every shortcut stays, so → steps the frame.
// ⌘ and ⌃ shortcuts and other keys always stay. macOS only.
import SwiftUI
@testable import SuiteUI
import Testing

@MainActor @Suite struct FocusedControlKeysTests {
    let stepKeys = [
        KeyboardShortcut(.rightArrow, modifiers: []), KeyboardShortcut(.leftArrow, modifiers: []),
        KeyboardShortcut(.rightArrow, modifiers: .option), KeyboardShortcut(.leftArrow, modifiers: .option),
        KeyboardShortcut(.home, modifiers: []), KeyboardShortcut(.end, modifiers: []),
        KeyboardShortcut(.space, modifiers: []),
    ]

    @Test func focusedBarTakesTheStepKeys() {
        for key in stepKeys {
            #expect(FocusedControlKeys.menuShortcut(key, controlHasKeys: true) == nil, "\(key.key) stayed the menu's")
        }
    }

    @Test func canvasOrTimelineFocusKeepsTheMenusKeys() {
        for key in stepKeys {
            #expect(FocusedControlKeys.menuShortcut(key, controlHasKeys: nil) == key)
        }
    }

    @Test func commandKeysAndOtherKeysStayTheMenus() {
        let kept = [
            KeyboardShortcut("k", modifiers: []), KeyboardShortcut("z"),
            KeyboardShortcut(.rightArrow, modifiers: .command), KeyboardShortcut(.delete, modifiers: []),
        ]
        for key in kept {
            #expect(FocusedControlKeys.menuShortcut(key, controlHasKeys: true) == key)
        }
        #expect(FocusedControlKeys.menuShortcut(nil, controlHasKeys: true) == nil)
    }
}
