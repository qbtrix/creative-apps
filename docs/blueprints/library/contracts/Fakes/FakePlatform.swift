// Fakes/FakePlatform.swift: fakes of the three platform contracts. The
// decoder "finds" the fixture's photos in any folder; the writer and the
// store keep bytes in memory, so tests read back what was written.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct FakeDecoder: PhotoDecoding {
    let photos: [PhotoItem]
    let mode: FakeMode
    public init(photos: [PhotoItem], mode: FakeMode = .ok) {
        self.photos = photos; self.mode = mode
    }

    public func scan(folder: String) async throws -> FolderScan {
        try await FakeBehavior.perform(mode, failing: .unreadableFolder(folder))
        let candidates = photos.map {
            ImportCandidate(path: folder + "/" + $0.name + ".jpg", captureDate: $0.captureDate,
                            pixelSize: $0.pixelSize, kind: .jpeg)
        }
        return FolderScan(candidates: candidates, failures: [])
    }

    public func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage {
        try await FakeBehavior.perform(mode, failing: .notAnImage(path))
        guard let photo = photos.first(where: { $0.path == path || $0.id == path }),
              let image = FakeBehavior.gradient(for: photo, longSide: maxLongSide)
        else { throw LibraryError.missingFile(path) }
        return image
    }
}

public actor FakeJPEGWriter: JPEGWriting {
    let mode: FakeMode
    /// Written files by "folder/name", for tests.
    public private(set) var files: [String: DisplayImage] = [:]
    public init(mode: FakeMode = .ok) { self.mode = mode }

    public func existingNames(in folder: String) async throws -> Set<String> {
        Set(files.keys.filter { $0.hasPrefix(folder + "/") }.map { String($0.dropFirst(folder.count + 1)) })
    }

    public func write(_ image: DisplayImage, quality: Int, folder: String, fileName: String) async throws {
        let key = folder + "/" + fileName
        try await FakeBehavior.perform(mode, failing: .writeFailed(path: key, reason: "The folder is read-only."))
        guard files[key] == nil else { throw LibraryError.writeFailed(path: key, reason: "The file already exists.") }
        files[key] = image
    }
}

public actor FakeCatalogStore: CatalogStoring {
    let mode: FakeMode
    public private(set) var data: Data?
    public private(set) var setAsideCount = 0
    public init(data: Data? = nil, mode: FakeMode = .ok) {
        self.data = data; self.mode = mode
    }
    public func read() async throws -> Data? { data }
    public func write(_ data: Data) async throws {
        try await FakeBehavior.perform(mode, failing: .writeFailed(path: "catalog.json", reason: "The disk is full."))
        self.data = data
    }
    public func setAside() async throws -> String {
        data = nil
        setAsideCount += 1
        return "catalog.json.bad"
    }
}
