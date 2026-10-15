// Fakes/FakeUseCases.swift: fakes of the import, thumbnail, culling and
// catalog coding contracts. Each does the simplest honest thing (import
// returns the fixture, thumbnails are gradients) and obeys
// `-LibraryFakeMode`, so the UI track can show every state. The loupe,
// develop, crop and export fakes live in FakeRendering.swift.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct FakeImporter: PhotoImporting {
    let photos: [PhotoItem]
    let mode: FakeMode
    public init(photos: [PhotoItem], mode: FakeMode = .ok) {
        self.photos = photos; self.mode = mode
    }
    public func importFolder(_ folder: String, known: Set<String>,
                             progress: @escaping @Sendable (ImportProgress) -> Void,
                             added: @escaping @Sendable ([PhotoItem]) -> Void) async throws -> ImportResult {
        if mode == .fail { throw LibraryError.unreadableFolder(folder) }
        let fresh = photos.filter { !known.contains($0.id) }
        // Progress first, so "Importing 1 of N" shows before the slow wait.
        progress(ImportProgress(done: 0, total: fresh.count))
        try await FakeBehavior.perform(mode, failing: .unreadableFolder(folder))
        for index in fresh.indices {
            if mode == .slow { try await Task.sleep(nanoseconds: 50_000_000) }
            if index > 0 { progress(ImportProgress(done: index, total: fresh.count)) }
            added([fresh[index]])
        }
        return ImportResult(added: fresh, alreadyKnown: photos.count - fresh.count, failures: [])
    }
}

public struct FakeThumbnails: ThumbnailProviding {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func thumbnail(for photo: PhotoItem, longSide: Int) async throws -> DisplayImage {
        try await FakeBehavior.perform(mode, failing: .notAnImage(photo.id))
        guard let image = FakeBehavior.gradient(for: FakeBehavior.cropShaped(photo, photo.develop.crop),
                                                longSide: longSide) else {
            throw LibraryError.notAnImage(photo.id)
        }
        return image
    }
    public func invalidate(_ id: String) async {}
}

/// Applies changes like the live one; Auto Advance is the plain rule (the
/// next id in `before`, staying on the last) without the filter case.
public struct FakeCulling: PhotoCulling {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func apply(_ change: CullChange, to ids: Set<String>, in items: [PhotoItem]) throws -> [PhotoItem] {
        if mode == .fail { throw LibraryError.invalid("Rating is unavailable in this preview.") }
        if case .rating(let stars) = change, !(0...5).contains(stars) {
            throw LibraryError.invalid("A rating is 0 to 5 stars.")
        }
        return items.map { item in
            guard ids.contains(item.id) else { return item }
            var copy = item
            switch change {
            case .rating(let stars): copy.rating = stars
            case .flag(let flag): copy.flag = flag
            case .label(let label): copy.label = label
            }
            return copy
        }
    }
    public func advance(from id: String, before: [String], after: [String]) -> String? {
        guard let index = before.firstIndex(of: id) else { return after.first }
        return index + 1 < before.count ? before[index + 1] : id
    }
}

/// Stores ids and ratings only, as text: enough to drive the restore journey on fakes.
public struct FakeCatalogCoding: CatalogCoding {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func encode(_ photos: [PhotoItem]) throws -> Data {
        Data(photos.map { "\($0.id)\t\($0.rating)" }.joined(separator: "\n").utf8)
    }
    public func decode(_ data: Data) throws -> [PhotoItem] {
        if mode == .fail { throw LibraryError.damagedCatalog("fake") }
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
        return try lines.map { line in
            let fields = line.split(separator: "\t")
            guard fields.count == 2, let rating = Int(fields[1]) else { throw LibraryError.damagedCatalog("fake") }
            return PhotoItem(id: String(fields[0]), name: String(fields[0]), captureDate: Date(timeIntervalSince1970: 0),
                             color: .init(0.5, 0.5, 0.5), rating: rating)
        }
    }
}
