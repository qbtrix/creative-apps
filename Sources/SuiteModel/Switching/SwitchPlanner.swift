// SwitchPlanner.swift: what a switch to an app does next, from the run state
// the switcher sees (blueprint 2.3, shell-apps). Foundation free, Linux-safe,
// Sendable.

/// What `AppLauncher.switchTo` does with a switch request.
public enum SwitchAction: Equatable, Sendable {
    case activate
    case open
    case refuse(SuiteError)
}

/// Picks the action for a switch: an app running with windows comes forward,
/// an app with no window or not running is opened, and a missing app is refused.
public enum SwitchPlanner {
    public static func action(for app: SuiteApp, state: AppRunState) -> SwitchAction {
        switch state {
        case .running(let windows) where windows > 0: .activate
        case .missing: .refuse(.appMissing(app))
        case .notRunning, .launching, .running: .open
        }
    }
}
