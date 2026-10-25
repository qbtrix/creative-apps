// DesignDocumentHost.swift (#5200): Design's `SuiteDocumentHost`, the one
// `.suiteEditor(.design, host:)` hands every received hand-off to. An `.open`
// (Open In from the launcher, the home's Recent, a .design opened in Finder)
// hands each document's path to `deliver`, which the app opens in an empty
// window or a new one; an open with nothing in it is refused. Every other verb
// is refused with Design's reason and delivers nothing. Linux-safe, Sendable.
import SuiteModel

public struct DesignDocumentHost: SuiteDocumentHost {
    /// Why Design refuses a verb other than open.
    public static let verbRefusal = SuiteError.notAvailable("\(SuiteApp.design.displayName) can't do that yet.")
    /// Why an open hand-off with no document is refused.
    public static let openNeedsDocument = SuiteError.notAvailable("Choose a design to open.")

    private let deliver: @Sendable ([String]) async -> Void

    /// A host that hands each accepted open's file paths, oldest first, to `deliver`.
    public init(deliver: @escaping @Sendable ([String]) async -> Void) {
        self.deliver = deliver
    }

    /// The paths an open hand-off asks Design to open, or why Design refuses `handOff`.
    public static func paths(for handOff: HandOff) -> Result<[String], SuiteError> {
        guard handOff.verb == .open else { return .failure(verbRefusal) }
        guard !handOff.documents.isEmpty else { return .failure(openNeedsDocument) }
        return .success(handOff.documents.map(\.path))
    }

    public func refusal(for handOff: HandOff) async -> SuiteError? {
        if case .failure(let reason) = Self.paths(for: handOff) { return reason }
        return nil
    }

    public func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState {
        switch Self.paths(for: handOff) {
        case .failure(let reason): throw reason
        case .success(let paths):
            await deliver(paths)
            return .accepted
        }
    }
}
