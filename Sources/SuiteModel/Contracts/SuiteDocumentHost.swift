// SuiteDocumentHost.swift: UC-18, act on a hand-off (every app, tier 1).
// Foundation free, Linux-safe, Sendable.

/// UC-18 Act on a hand-off (every app, tier 1). Each `<X>Model` conforms
/// (adoption issue A-x-1); `.suiteApp(_:host:)` in SuiteShell hands every
/// received hand-off to it. SuiteShell never sees an app Model, only this.
public protocol SuiteDocumentHost: Sendable {
    /// nil when the app can act on it now; else the reason it refuses.
    func refusal(for handOff: HandOff) async -> SuiteError?
    /// Open, new, edit, place, import or return: the app does it and says how it ended.
    func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState
}
