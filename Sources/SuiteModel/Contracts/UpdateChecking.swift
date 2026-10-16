// UpdateChecking.swift: a suite contract from blueprint suite.md 5.2. Every throwing
// requirement throws `SuiteError`, whose `message` is the sentence the UI shows.

/// UC-14 One updater (tier 2). Live: URLSession download, CryptoKit Ed25519
/// verify, replace the bundle (in AfterGlowApp).
public protocol UpdateChecking: Sendable {
    func check(current: SuiteVersion) async throws(SuiteError) -> UpdateOffer?
    /// Downloads and verifies; returns the local path of the verified zip.
    func download(_ offer: UpdateOffer) async throws(SuiteError) -> String
    /// Asks every running suite app to quit (each runs its own unsaved flow), then replaces and relaunches.
    /// `.updatePostponed(app)` when an app cancelled its quit; nothing is replaced.
    func install(zipAt path: String) async throws(SuiteError)
}
