// SettingsRouting.swift: a suite contract from blueprint suite.md 5.2. Every throwing
// requirement throws `SuiteError`, whose `message` is the sentence the UI shows.

/// UC-12 Open the one Settings window at a pane from any app (tier 2).
/// Live: an `.openSettings` hand-off to the launcher.
public protocol SettingsRouting: Sendable {
    func open(_ pane: SettingsPane, from app: SuiteApp) async throws(SuiteError)
}
