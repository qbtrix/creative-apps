// SwitchMenu.swift: the six Window > Switch To items (blueprint 6.2). Home and
// the five apps, each with its Control-Command digit, disabled with the
// sentence that says why when it can't act. Foundation free, Linux-safe,
// Sendable.

/// One Window > Switch To item.
public struct SwitchMenuItem: Equatable, Sendable {
    public var app: SuiteApp
    public var title: String
    public var digit: Int
    public var enabled: Bool
    /// The sentence a disabled item shows; nil when it is enabled.
    public var reason: String?

    public init(app: SuiteApp, title: String, digit: Int, enabled: Bool, reason: String?) {
        self.app = app; self.title = title; self.digit = digit; self.enabled = enabled; self.reason = reason
    }
}

/// The Switch To items in order: Home, Flare, Design, Photo, Library, Halo.
public enum SwitchMenu {
    public static func items(current: SuiteApp, states: [SuiteApp: AppRunState]) -> [SwitchMenuItem] {
        ([SuiteApp.launcher] + SuiteApp.apps).map { app in
            let reason = reason(for: app, current: current, state: states[app] ?? .notRunning)
            return SwitchMenuItem(app: app, title: title(for: app, current: current), digit: app.switchDigit,
                                  enabled: reason == nil, reason: reason)
        }
    }

    private static func title(for app: SuiteApp, current: SuiteApp) -> String {
        if app == current { return "Show \(app.displayName) Window" }
        return app == .launcher ? "Home" : app.displayName
    }

    private static func reason(for app: SuiteApp, current: SuiteApp, state: AppRunState) -> String? {
        if state == .missing { return SuiteError.appMissing(app).message }
        if app == current, case .running(let windows) = state, windows > 0 { return "You're in \(app.displayName)." }
        return nil
    }
}
