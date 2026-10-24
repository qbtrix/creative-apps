// FlareDocumentHost.swift: finding #4636 (file-flow FL-2). Flare's
// `SuiteDocumentHost`, the one `.suiteApp(.flare, host:)` and the stage's
// drop hand every hand-off to. An `.open` (a .flare dropped on the stage,
// File > Open Recent ▸, Open In from another app) becomes one
// `FlareFileRequest.open(path:)` per animation, which the app opens in a new
// window; an open with nothing in it is refused. `.new` is accepted and asks
// for nothing: launching Flare already shows a window. A placed SVG is
// refused with "Flare can't import SVG yet." until SVG import (E11), and
// every other verb with Flare's reason; a refusal delivers nothing.
// Linux-safe, Sendable.
import SuiteModel

public struct FlareDocumentHost: SuiteDocumentHost {
    /// Why an open hand-off with no animation is refused.
    public static let openNeedsAnimation = SuiteError.notAvailable("Choose an animation to open.")

    private let deliver: @Sendable ([FlareFileRequest]) async -> Void

    /// A host that hands each accepted hand-off's requests to `deliver`.
    public init(deliver: @escaping @Sendable ([FlareFileRequest]) async -> Void) {
        self.deliver = deliver
    }

    /// What the app does for `handOff`, oldest first, or why Flare refuses it.
    public static func requests(for handOff: HandOff) -> Result<[FlareFileRequest], SuiteError> {
        switch handOff.verb {
        case .open:
            guard !handOff.documents.isEmpty else { return .failure(openNeedsAnimation) }
            return .success(handOff.documents.map { .open(path: $0.path) })
        case .new:
            return .success([])
        case .place:
            let svg = handOff.documents.contains { $0.type == .svg || $0.path.lowercased().hasSuffix(".svg") }
            return .failure(svg ? .notAvailable(FlareWorkspace.svgRefusal) : FlareWorkspace.handOffRefusal)
        case .edit, .importAnimation, .returnEdit, .openSettings:
            return .failure(FlareWorkspace.handOffRefusal)
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
