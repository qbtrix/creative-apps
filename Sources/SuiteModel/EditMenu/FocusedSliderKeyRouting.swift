// FocusedSliderKeyRouting.swift (editor-menus, #2487): where an editor's
// plain-arrow menu item goes while an inspector slider has the keys. Flare's
// Animate menu binds ← and → to Step Back and Step Forward, and AppKit offers
// a key to the menu bar before the focused view, so a focused Rotation bar
// never saw its arrows: the playhead moved instead (#2487). Captain,
// 2026-10-24: while a slider has focus, ← and → adjust it, as on any Mac; the
// menu's frame step applies only when the canvas or timeline has focus. So
// while a slider has focus, an arrow key that reaches the item goes on to the
// slider, and the item stays on (a disabled item would swallow the key). A
// click on the item in the menu still runs the app's action, and so does a
// key with no slider focused. SuiteUI's MenuCommand.givingWayToSlider() acts
// on this.

/// Where a plain-arrow item sends its action.
public enum SliderKeyRoute: Equatable, Sendable {
    /// The key goes on to the focused slider, which steps its value.
    case slider
    /// The app's own action (Step Forward, Step Back).
    case app
}

/// One plain-arrow item as the focus leaves it: where a press goes, whether it is on, and its help.
public struct SliderKeyItem: Equatable, Sendable {
    public let route: SliderKeyRoute
    public let isEnabled: Bool
    public let help: String

    public init(route: SliderKeyRoute, isEnabled: Bool, help: String) {
        self.route = route
        self.isEnabled = isEnabled
        self.help = help
    }
}

public enum FocusedSliderKeyRouting {
    /// The item's help while a slider has the arrows.
    public static let sliderHelp = "The focused slider takes ← and →; click the canvas or timeline to step frames."

    /// The item given whether a slider has focus and whether this press came from its key (`fromKey`, not a click in
    /// the menu), where the app's own item is `appEnabled` with `appHelp`.
    public static func item(sliderFocused: Bool, fromKey: Bool, appEnabled: Bool, appHelp: String) -> SliderKeyItem {
        guard sliderFocused else {
            return SliderKeyItem(route: .app, isEnabled: appEnabled, help: appHelp)
        }
        let route: SliderKeyRoute = fromKey ? .slider : .app
        return SliderKeyItem(route: route, isEnabled: appEnabled || route == .slider, help: sliderHelp)
    }
}
