// AppSwitching.swift: UC-1, switch between apps (tier 1). Every throwing
// requirement throws `SuiteError`, whose `message` is the sentence the UI
// shows. Foundation free, Linux-safe, Sendable.

/// UC-1 Switch between apps (tier 1). Live: SuiteShell `AppLauncher`
/// (NSRunningApplication.activate, else NSWorkspace.openApplication).
public protocol AppSwitching: Sendable {
    func runState(of app: SuiteApp) async -> AppRunState
    /// Yields a counter each time any app's run state changes (launch, quit, crash).
    func changes() async -> AsyncStream<Int>
    /// Brings the app forward, launching it if needed; never opens a document.
    func switchTo(_ app: SuiteApp, reason: SwitchReason) async throws(SuiteError) -> SwitchReceipt
}
