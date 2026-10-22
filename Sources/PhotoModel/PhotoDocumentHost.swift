// PhotoDocumentHost.swift: finding #4260. Photo's `SuiteDocumentHost`, the
// one `.suiteApp(.photo, host:)` hands every received hand-off to. An `.open`
// (File > Open Recent ▸, Open In from another app, a file the home routes
// here) becomes one `PhotoFileRequest.open(path:)` per image, which the app
// opens in an empty window or a new one; an open with nothing in it is
// refused. `.new` and `.place` are accepted and ask for nothing: launching
// Photo already shows an empty window, and a drop places through the
// window's own workspace. Every other verb is refused with a reason and
// delivers nothing. Linux-safe, Sendable.
import SuiteModel

public struct PhotoDocumentHost: SuiteDocumentHost {
    /// Why Photo refuses a verb other than open, new and place.
    public static let verbRefusal = PhotoWorkspace.handOffRefusal
    /// Why an open hand-off with no image is refused.
    public static let openNeedsImage = SuiteError.notAvailable("Choose an image to open.")

    private let deliver: @Sendable ([PhotoFileRequest]) async -> Void

    /// A host that hands each accepted hand-off's requests to `deliver`.
    public init(deliver: @escaping @Sendable ([PhotoFileRequest]) async -> Void) {
        self.deliver = deliver
    }

    /// What the app does for `handOff`, oldest first, or why Photo refuses it.
    public static func requests(for handOff: HandOff) -> Result<[PhotoFileRequest], SuiteError> {
        switch handOff.verb {
        case .open:
            guard !handOff.documents.isEmpty else { return .failure(openNeedsImage) }
            return .success(handOff.documents.map { .open(path: $0.path) })
        case .new, .place:
            return .success([])
        case .edit, .importAnimation, .returnEdit, .openSettings:
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
            if !requests.isEmpty { await deliver(requests) }
            return .accepted
        }
    }
}
