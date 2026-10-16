// HandOffSending.swift: UC-5, send a hand-off to another process (tier 1).
// Foundation free, Linux-safe, Sendable.

/// UC-5 Send a hand-off to another process (tier 1: home opens and new
/// documents ride on it). Live: SuiteShell `HandOffTransport`.
public protocol HandOffSending: Sendable {
    func send(_ handOff: HandOff) async throws(SuiteError) -> SwitchReceipt
}
