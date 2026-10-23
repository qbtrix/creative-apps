// ReopenRule.swift (editor-menus EM-1, EM-2): whether a Dock click (a reopen
// event) on a running suite editor opens a new window (#1081). SuiteAppDelegate
// asks it from applicationShouldHandleReopen. An app launched hidden to take a
// hand-off gets a reopen event with the hand-off and stays without a window;
// otherwise a click with no window visible brings one back. Foundation free,
// Linux-safe.

public enum ReopenRule {
    /// True when the click should open a window: none is visible and the app
    /// was not launched hidden to take a hand-off.
    public static func shouldOpenWindow(visibleWindows: Int, launchedHidden: Bool) -> Bool {
        guard !launchedHidden else { return false }
        return visibleWindows == 0
    }
}
