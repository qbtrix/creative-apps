// Live/LiveImporter.swift: the live J1 import. Scans a folder through the
// decoder, skips paths the catalog already holds, and hands the new photos
// over in capture-date order: in batches of at most 50 (at least every
// 250 ms) while it runs, with progress at most 30 times a second, then all of
// them in the result. The clock is a parameter so tests drive time without
// sleeping. Stops at the next photo once its task is cancelled. `copying` makes it copy each new photo under
// `copyTo` first (catalog-files LC-5), by ImportCopyPlan's names; a copy that comes up short is refused and the
// photo is a FileFailure, never added in place.
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
    /// Where new photos are copied before they are added; `copyTo` nil adds them in place.
    var copy = ImportCopyOptions()

    public init(decoder: any PhotoDecoding) {
        let start = ContinuousClock.now
        self.init(decoder: decoder, now: { ContinuousClock.now - start })
    }

    init(decoder: any PhotoDecoding, now: @escaping @Sendable () -> Duration) {
        self.decoder = decoder; self.now = now
    }

    public func copying(_ options: ImportCopyOptions) -> any PhotoImporting {
        var importer = self
        importer.copy = options
        return importer
    }

    public func importFolder(_ folder: String, known: Set<String>,
                             progress: @escaping @Sendable (ImportProgress) -> Void,
                             added: @escaping @Sendable ([PhotoItem]) -> Void) async throws -> ImportResult {
        let scan = try await decoder.scan(folder: folder)
        if scan.candidates.isEmpty && scan.failures.isEmpty { throw LibraryError.noPhotos(Self.lastComponent(folder)) }
        let fresh = scan.candidates.filter { !known.contains($0.path) }
            .sorted { ($0.captureDate, $0.path) < ($1.captureDate, $1.path) }
        let total = fresh.count
        let destinations = Self.destinations(fresh, options: copy)
        var failures = scan.failures
        var done = 0
        var all: [PhotoItem] = []
        var batch: [PhotoItem] = []
        var lastFlush = now()
        var lastProgress = lastFlush
        progress(ImportProgress(done: 0, total: total))
        var reported = 0
        for candidate in fresh {
            done += 1
            var path: String? = candidate.path
            if let destination = destinations[candidate.path] {
                do { try Self.copy(ImportCopyStep(source: candidate.path, destination: destination)); path = destination } catch {
                    path = nil
                    failures.append(FileFailure(path: candidate.path, reason: (error as? LibraryError)?.message ?? "couldn't be copied"))
                }
            }
            if let path {
                let photo = PhotoItem(id: path, name: Self.fileStem(candidate.path), captureDate: candidate.captureDate,
                                      color: Self.neutralGrey, path: path, pixelSize: candidate.pixelSize, camera: candidate.camera)
                all.append(photo); batch.append(photo)
            }
            let time = now()
            if time - lastProgress >= Self.progressInterval {
                progress(ImportProgress(done: done, total: total))
                reported = done; lastProgress = time
            }
            if batch.count >= Self.batchSize || time - lastFlush >= Self.flushInterval {
                added(batch); batch = []; lastFlush = time
            }
            if Task.isCancelled { break }
        }
        if !batch.isEmpty { added(batch) }
        if reported != done { progress(ImportProgress(done: done, total: total)) }
        return ImportResult(added: all, alreadyKnown: scan.candidates.count - total, failures: failures)
    }

    /// Each fresh photo's copy path under `options.copyTo` by source path; empty when it adds in place. The
    /// candidate's date is already its capture date, else its file's.
    static func destinations(_ fresh: [ImportCandidate], options: ImportCopyOptions) -> [String: String] {
        let sources = fresh.map { (path: $0.path, captured: Optional($0.captureDate), modified: $0.captureDate) }
        let steps = ImportCopyPlan.plan(sources, options: options) { FileManager.default.fileExists(atPath: $0) }
        return Dictionary(steps.map { ($0.source, $0.destination) }, uniquingKeysWith: { first, _ in first })
    }

    /// Copies `step.source` to a hidden name beside `step.destination`, checks the copy is as long as the source,
    /// then moves it into place, which never replaces a file. A short copy is removed and throws `writeFailed`.
    static func copy(_ step: ImportCopyStep,
                     copyFile: (String, String) throws -> Void = { try FileManager.default.copyItem(atPath: $0, toPath: $1) }) throws {
        let files = FileManager.default
        let name = lastComponent(step.destination)
        let folder = String(step.destination.dropLast(name.count))
        try files.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let partial = folder + "." + name + "." + UUID().uuidString + ".partial"
        do {
            try copyFile(step.source, partial)
            guard let length = size(step.source), size(partial) == length else {
                throw LibraryError.writeFailed(path: step.destination, reason: "The copy of \(name) came up short.")
            }
            try files.moveItem(atPath: partial, toPath: step.destination)
        } catch {
            try? files.removeItem(atPath: partial)
            throw error
        }
    }

    /// The file's length in bytes; nil when it can't be read.
    static func size(_ path: String) -> Int? {
        guard let value = try? FileManager.default.attributesOfItem(atPath: path)[.size] else { return nil }
        if let bytes = value as? Int { return bytes }
        if let bytes = value as? UInt64 { return Int(exactly: bytes) }
        return (value as? Int64).flatMap { Int(exactly: $0) }
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
