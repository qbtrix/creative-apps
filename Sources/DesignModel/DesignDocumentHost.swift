// DesignDocumentHost.swift (#5200, #3333): Design's `SuiteDocumentHost`, the
// one `.suiteEditor(.design, host:)` hands every received hand-off to. An
// `.open` (Open In from the launcher, the home's Recent, a .design opened in
// Finder) delivers one `.open(path:)` per document, which the app opens in an
// empty window or a new one; an open with nothing in it is refused. A `.new`
// (the home's New Design, the welcome's Blank) delivers one `.newFile`, which
// starts an untitled design the same way. Every other verb is refused with
// Design's reason and delivers nothing. Linux-safe, Sendable.
import SuiteModel

public struct DesignDocumentHost: SuiteDocumentHost {
    /// Why Design refuses a verb other than open and new.
    public static let verbRefusal = SuiteError.notAvailable("\(SuiteApp.design.displayName) can't do that yet.")
    /// Why an open hand-off with no document is refused.
    public static let openNeedsDocument = SuiteError.notAvailable("Choose a design to open.")

    /// What an accepted hand-off asks the app for: a file to open, or a new file.
    public enum Request: Equatable, Sendable {
        case open(path: String)
        case newFile
    }

    private let deliver: @Sendable ([Request]) async -> Void

    /// A host that hands each accepted hand-off's requests, oldest first, to `deliver`.
    public init(deliver: @escaping @Sendable ([Request]) async -> Void) {
        self.deliver = deliver
    }

    /// What `handOff` asks Design for, or why Design refuses it.
    public static func requests(for handOff: HandOff) -> Result<[Request], SuiteError> {
        switch handOff.verb {
        case .open:
            guard !handOff.documents.isEmpty else { return .failure(openNeedsDocument) }
            return .success(handOff.documents.map { .open(path: $0.path) })
        case .new:
            return .success([.newFile])
        case .place, .edit, .importAnimation, .returnEdit, .openSettings:
            return .failure(verbRefusal)
        }
    }

    public func refusal(for handOff: HandOff) async -> SuiteError? {
        if case .failure(let reason) = Self.requests(for: handOff) { return reason }
        return nil
    }

    public func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState {
        switch Self.requests(for: handOff) {
        case .failure(let reason): throw reason
        case .success(let requests):
            await deliver(requests)
            return .accepted
        }
    }
}
