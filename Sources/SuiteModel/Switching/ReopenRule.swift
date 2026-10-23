// ReopenRule.swift (editor-menus EM-1): whether a Dock click (a reopen event)
// on a running suite editor opens a new window. SuiteAppDelegate asks it from
// applicationShouldHandleReopen. Foundation free, Linux-safe.

public enum ReopenRule {
    /// True when the click should open a window: none is visible and the app
    /// was not launched hidden to take a hand-off.
    public static func shouldOpenWindow(visibleWindows: Int, launchedHidden: Bool) -> Bool {
        false
    }
}
