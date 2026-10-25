// HaloDocumentHost.swift: A-HA-1 (#865). Halo's `SuiteDocumentHost`, the
// one `.suiteApp(.halo, host:)` hands every received hand-off to. A `.new`
// hand-off (the home's New Composition tile) becomes `.newComposition`, the
// window's New Composition sheet; an `.open` of a .halo project
// (`org.creativesuite.halo.project`, or any file named .halo) becomes
// `.openRecent(path)`, the window's open path, which asks about unsaved
// changes first. Every other verb, and an open with no Halo project in it,
// is refused with a reason and delivers nothing. HaloProject is a value the
// window owns, so the host hands its command to `deliver`, which the app
// routes to the window's `perform`. Linux-safe, Sendable.
import SuiteModel

public struct HaloDocumentHost: SuiteDocumentHost {
    /// Why Halo refuses a verb other than open and new.
    public static let verbRefusal = SuiteError.notAvailable("Halo can't do that yet.")
    /// Why an open hand-off with no document is refused.
    public static let openNeedsProject = SuiteError.notAvailable("Choose a Halo project to open.")

    private let deliver: @Sendable (HaloCommand) async -> Void

    /// A host that hands each accepted hand-off's command to `deliver`.
    public init(deliver: @escaping @Sendable (HaloCommand) async -> Void) {
        self.deliver = deliver
    }

    /// The window command `handOff` asks for, or why Halo refuses it.
    public static func command(for handOff: HandOff) -> Result<HaloCommand, SuiteError> {
        switch handOff.verb {
        case .new:
            return .success(.newComposition)
        case .open:
            if let project = handOff.documents.first(where: isProject) { return .success(.openRecent(project.path)) }
            guard let other = handOff.documents.first else { return .failure(openNeedsProject) }
            return .failure(.unsupportedFile(name: other.displayName))
        case .edit, .place, .importAnimation, .returnEdit, .openSettings:
            return .failure(verbRefusal)
        }
    }

    /// A Halo project: its suite type, or a .halo file name.
    private static func isProject(_ document: SuiteDocumentRef) -> Bool {
        document.type == .haloProject || document.path.lowercased().hasSuffix(".halo")
    }

    public func refusal(for handOff: HandOff) async -> SuiteError? {
        if case .failure(let reason) = Self.command(for: handOff) { return reason }
        return nil
    }

    public func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState {
        switch Self.command(for: handOff) {
        case .failure(let reason): throw reason
        case .success(let command):
            await deliver(command)
            return .accepted
        }
    }
}
