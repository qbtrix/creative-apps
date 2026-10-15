// Fakes/FakeDocuments.swift: the document fakes (blueprint 5.2), for building
// views and journeys before PV-1. Each is deterministic and does the least
// that still changes something a journey can see. None reads the file
// system, and none shares state with another instance: `PhotoServices.fake`
// makes new ones on every read, so parallel tests never see each other's
// documents. A test fails if `.live` holds any Fake (LiveServicesTests).
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import Synchronization

/// Writes a one-line manifest and each image as raw bytes, no codec, and
/// gives back the last snapshot this instance wrote.
public final class FakeArchive: DocumentArchiving {
    private let last = Mutex<PhotoDocumentSnapshot?>(nil)
    public var unavailableHelp: String? { nil }
    public var formatVersion: Int { 1 }
    public init() {}

    public func encode(_ snapshot: PhotoDocumentSnapshot, codec: any PhotoImageCodec) throws -> PhotoPackage {
        var files: [String: Data] = ["document.txt": Data("fake \(snapshot.canvas.width)x\(snapshot.canvas.height)".utf8)]
        for (id, image) in snapshot.pixels { files["layers/\(id).raw"] = Data(image.rgba8) }
        last.withLock { $0 = snapshot }
        return PhotoPackage(files: files)
    }

    public func decode(_ package: PhotoPackage, codec: any PhotoImageCodec) throws -> PhotoDocumentSnapshot {
        guard package.files["document.txt"] != nil, let snapshot = last.withLock({ $0 }) else {
            throw ArchiveError.notADocument
        }
        return snapshot
    }

    public func container(_ package: PhotoPackage) throws -> Data {
        package.files["document.txt"] ?? Data()
    }

    public func package(fromContainer data: Data) throws -> PhotoPackage {
        guard String(decoding: data, as: UTF8.self).hasPrefix("fake ") else { throw ArchiveError.notADocument }
        return PhotoPackage(files: ["document.txt": data])
    }
}

/// Keeps entries in memory per window.
public final class FakeRecovery: RecoveryStoring {
    private let entries = Mutex<[String: RecoveryEntry]>([:])
    public var unavailableHelp: String? { nil }
    public init() {}
    public func write(_ entry: RecoveryEntry, window: String) throws { entries.withLock { $0[window] = entry } }
    public func leftBehind() throws -> [RecoveryEntry] {
        entries.withLock { $0.values.sorted { $0.savedAt > $1.savedAt } }
    }
    public func discard(window: String) throws { _ = entries.withLock { $0.removeValue(forKey: window) } }
    public func discardAll() throws { entries.withLock { $0 = [:] } }
}
