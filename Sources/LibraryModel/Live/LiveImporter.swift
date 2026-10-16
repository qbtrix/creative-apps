// Live/LiveImporter.swift: the live J1 import. Scans a folder through the
// decoder, skips paths the catalog already holds, and hands the new photos
// over in capture-date order: in batches of at most 50 (at least every
// 250 ms) while it runs, with progress at most 30 times a second, then all of
// them in the result. The clock is a parameter so tests drive time without
// sleeping. Stops at the next photo once its task is cancelled.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import CoreRaster

public struct LiveImporter: PhotoImporting {
    public static let unavailable: String? = nil
    static let batchSize = 50
    static let flushInterval = Duration.milliseconds(250)
    static let progressInterval = Duration.seconds(1) / 30
    /// Imported photos stand in as this until thumbnails draws them.
    static let neutralGrey = Color3(0.5, 0.5, 0.5)

    let decoder: any PhotoDecoding
    /// Time since some fixed start; only differences are used.
    let now: @Sendable () -> Duration

    public init(decoder: any PhotoDecoding) {
        let start = ContinuousClock.now
        self.init(decoder: decoder, now: { ContinuousClock.now - start })
    }

    init(decoder: any PhotoDecoding, now: @escaping @Sendable () -> Duration) {
        self.decoder = decoder; self.now = now
    }

    public func importFolder(_ folder: String, known: Set<String>,
                             progress: @escaping @Sendable (ImportProgress) -> Void,
                             added: @escaping @Sendable ([PhotoItem]) -> Void) async throws -> ImportResult {
        let scan = try await decoder.scan(folder: folder)
        if scan.candidates.isEmpty && scan.failures.isEmpty { throw LibraryError.noPhotos(Self.lastComponent(folder)) }
        let fresh = scan.candidates.filter { !known.contains($0.path) }
            .sorted { ($0.captureDate, $0.path) < ($1.captureDate, $1.path) }
        let total = fresh.count
        var all: [PhotoItem] = []
        var batch: [PhotoItem] = []
        var lastFlush = now()
        var lastProgress = lastFlush
        progress(ImportProgress(done: 0, total: total))
        var reported = 0
        for candidate in fresh {
            let photo = PhotoItem(id: candidate.path, name: Self.fileStem(candidate.path),
                                  captureDate: candidate.captureDate, color: Self.neutralGrey,
                                  path: candidate.path, pixelSize: candidate.pixelSize)
            all.append(photo); batch.append(photo)
            let time = now()
            if time - lastProgress >= Self.progressInterval {
                progress(ImportProgress(done: all.count, total: total))
                reported = all.count; lastProgress = time
            }
            if batch.count >= Self.batchSize || time - lastFlush >= Self.flushInterval {
                added(batch); batch = []; lastFlush = time
            }
            if Task.isCancelled { break }
        }
        if !batch.isEmpty { added(batch) }
        if reported != all.count { progress(ImportProgress(done: all.count, total: total)) }
        return ImportResult(added: all, alreadyKnown: scan.candidates.count - total, failures: scan.failures)
    }

    /// "Shots" for "/Users/me/Shots/"; the whole string when it has no name.
    static func lastComponent(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    /// "IMG_0001" for "/Shots/IMG_0001.jpg"; a leading dot is part of the name.
    static func fileStem(_ path: String) -> String {
        let name = lastComponent(path)
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return name }
        return String(name[..<dot])
    }
}
