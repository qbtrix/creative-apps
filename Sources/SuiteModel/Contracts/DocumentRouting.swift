// DocumentRouting.swift: UC-4, route a file to its app and list Open In
// targets (tier 1 and 2). Foundation free, Linux-safe, Sendable.

/// UC-4 Route a file to its app, and list Open In targets (tier 1 and 2). Pure.
public protocol DocumentRouting: Sendable {
    /// The app a file opens in, or `.unsupportedFile`.
    func route(fileName: String) throws(SuiteError) -> SuiteApp
    /// Other apps that read this type, default first, never `from` itself.
    func openInTargets(for type: SuiteTypeID, from app: SuiteApp) -> [SuiteApp]
    /// nil when Open In has targets; else why the submenu is disabled.
    func openInRefusal(for type: SuiteTypeID, from app: SuiteApp) -> SuiteError?
}
