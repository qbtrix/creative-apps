// MenuCommand+Slider.swift (editor-menus, #2487): the one way an editor's
// plain-arrow menu item gives way to a focused inspector slider. AppKit offers
// a key to the menu bar before the focused view, so Flare's Step Forward (→)
// and Step Back (←) took the arrows from a focused Rotation bar. Wrapped,
// `item.givingWayToSlider()`: while a ScrubField has the keys
// (SuiteSliderFocus), the item stays on and a key press that reaches it goes
// on to the key window's first responder, the focused bar, which steps its
// value; a click on the item in the menu, or a key with no slider focused,
// runs the app's item as the app built it. SuiteModel's
// FocusedSliderKeyRouting decides.
import AppKit
import SuiteModel
import SwiftUI

/// Which ScrubField has the keys now, if any; each field sets and clears its own token.
@MainActor @Observable public final class SuiteSliderFocus {
    public static let shared = SuiteSliderFocus()
    public private(set) var focused: UUID?

    private init() {}

    /// `token`'s field took the keys (`true`) or lost them; losing them clears only its own token.
    public func update(_ token: UUID, isFocused: Bool) {
        if isFocused {
            focused = token
        } else if focused == token {
            focused = nil
        }
    }

    /// Runs `item`: a key press goes on to the focused slider, else the app's item while it can run.
    public static func run(_ item: MenuCommand) {
        let event = NSApp.currentEvent
        let now = FocusedSliderKeyRouting.item(
            sliderFocused: shared.focused != nil, fromKey: event?.type == .keyDown, appEnabled: item.isEnabled,
            appHelp: item.help)
        switch now.route {
        case .slider:
            if let event { NSApp.keyWindow?.firstResponder?.keyDown(with: event) }
        case .app:
            if now.isEnabled { item.perform() }
        }
    }
}

/// A plain-arrow item that gives way to a focused slider (`MenuCommand.givingWayToSlider()`).
public struct SliderKeyMenuItem: View {
    let item: MenuCommand

    public var body: some View {
        let entry = FocusedSliderKeyRouting.item(
            sliderFocused: SuiteSliderFocus.shared.focused != nil, fromKey: true, appEnabled: item.isEnabled,
            appHelp: item.help)
        let item = item
        MenuCommand(
            item.title, systemImage: item.systemImage, shortcut: item.shortcut, help: entry.help,
            isEnabled: entry.isEnabled, role: item.role
        ) { SuiteSliderFocus.run(item) }
    }
}

extension MenuCommand {
    /// This item, handing its key to a focused slider: on while one has focus, and stepping it.
    public func givingWayToSlider() -> SliderKeyMenuItem {
        SliderKeyMenuItem(item: self)
    }
}
