// PhotoDocumentHost.swift: finding #4260. Photo's `SuiteDocumentHost`, the
// one `.suiteApp(.photo, host:)` hands every received hand-off to. An `.open`
// (File > Open Recent ▸, Open In from another app, a file the home routes
// here) becomes one `PhotoFileRequest.open(path:)` per image, which the app
// opens in an empty window or a new one; an open with nothing in it is
// refused. `.new` (the home's New Photo, #3648) asks for one new image at
// the preset's `width` and `height`, 1920 x 1080 when it names none; `.place`
// is accepted and asks for nothing, since a drop places through the window's
// own workspace. Every other verb is refused with a reason and delivers
// nothing. Linux-safe, Sendable.
//
// Editor menus (EM-3): the live channel runs a catalog command on a copy of
// the front window's workspace and hands the copy back; the window adopts it
// unless its image moved on since the copy was taken (a newer `revision`), so
// a late answer never overwrites newer edits.
import SuiteModel

public struct PhotoDocumentHost: SuiteDocumentHost {
    /// Why Photo refuses a verb other than open, new and place.
    public static let verbRefusal = PhotoWorkspace.handOffRefusal
    /// Why an open hand-off with no image is refused.
    public static let openNeedsImage = SuiteError.notAvailable("Choose an image to open.")
    /// A new image's size when the hand-off's preset names none.
    public static let newImageSize = (width: 1920, height: 1080)

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
        case .new:
            return .success([newImage(for: handOff.preset)])
        case .place:
            return .success([])
        case .edit, .importAnimation, .returnEdit, .openSettings:
            return .failure(verbRefusal)
        }
    }

    /// The new image a `.new` hand-off asks for: the preset's whole, positive
    /// `width` and `height` parameters, else `newImageSize`'s for each.
    public static func newImage(for preset: NewDocumentPreset?) -> PhotoFileRequest {
        func side(_ key: String, _ fallback: Int) -> Int {
            guard let value = preset?.parameters[key].flatMap({ Int($0) }), value > 0 else { return fallback }
            return value
        }
        return .newImage(width: side("width", newImageSize.width), height: side("height", newImageSize.height))
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

extension PhotoWorkspace {
    /// Becomes `result`, a copy of this workspace a live command ran on; ignored
    /// when this workspace has edits the copy doesn't (a newer `revision`).
    public mutating func adoptLiveCommand(_ result: PhotoWorkspace) {
        guard result.revision >= revision else { return }
        self = result
    }
}
