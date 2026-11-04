// HomePreviews.swift: the home's Recent card previews (shared-thumbnails ST-3).
// Each document asks `preview(for:)` once for the window's life; a nil answer
// shows the app's mark. Generic over the picture so it runs on Linux. Linux-safe.
import Observation
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What a Recent card shows: not answered yet, the published preview, or the app's mark.
public enum HomePreviewKind: Equatable, Sendable { case waiting, preview, mark }

extension HomeModel {
    /// The publishing contract the previews are read from.
    public var thumbnails: any ThumbnailPublishing { services.thumbnails }
}

@MainActor @Observable
public final class HomePreviews<Picture> {
    /// Decoded previews by `SuiteDocumentRef.fileID`.
    public private(set) var pictures: [String: Picture] = [:]
    /// The fileIDs whose `preview(for:)` has answered, with a preview or nil.
    public private(set) var answered: Set<String> = []
    /// How many times `preview(for:)` was asked.
    @ObservationIgnored public private(set) var requests = 0
    @ObservationIgnored private var asked: Set<String> = []
    @ObservationIgnored private var marks: [SuiteApp: Picture] = [:]
    @ObservationIgnored private let decode: @MainActor (Data) -> Picture?
    @ObservationIgnored private let mark: @MainActor (SuiteApp) -> Picture?

    /// `decode` reads preview bytes (nil shows the mark); `mark` draws an app's mark, once per app.
    public init(decode: @escaping @MainActor (Data) -> Picture?, mark: @escaping @MainActor (SuiteApp) -> Picture?) {
        self.decode = decode; self.mark = mark
    }

    /// Asks for each document not asked before, then publishes every answer at once: one change, not one per card.
    public func load(_ refs: [SuiteDocumentRef], from thumbnails: any ThumbnailPublishing) async {
        var found: [String: Picture] = [:]
        var done: [String] = []
        for ref in refs where !asked.contains(ref.fileID) {
            asked.insert(ref.fileID)
            requests += 1
            if let data = await thumbnails.preview(for: ref), let picture = decode(data) { found[ref.fileID] = picture }
            done.append(ref.fileID)
        }
        guard !done.isEmpty else { return }
        pictures.merge(found) { _, new in new }
        answered.formUnion(done)
    }

    public func kind(for ref: SuiteDocumentRef) -> HomePreviewKind {
        if pictures[ref.fileID] != nil { return .preview }
        return answered.contains(ref.fileID) ? .mark : .waiting
    }

    /// The preview, else `fallback` (the recents' own thumbnail), else the mark once answered; nil while waiting.
    public func picture(for ref: SuiteDocumentRef, fallback: Picture?) -> Picture? {
        if let picture = pictures[ref.fileID] { return picture }
        if let fallback { return fallback }
        guard answered.contains(ref.fileID) else { return nil }
        if let cached = marks[ref.app] { return cached }
        let drawn = mark(ref.app)
        marks[ref.app] = drawn
        return drawn
    }
}
