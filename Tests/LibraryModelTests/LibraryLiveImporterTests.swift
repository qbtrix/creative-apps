// LibraryLiveImporterTests.swift: LiveImporter over a scripted decoder on a
// test clock (IM-2): known paths skipped, capture-date order, path ids, file
// stem names, batches of at most 50, progress at most 30 times a simulated
// second, scan errors passed through, and cancellation.
import Foundation
import Testing
import CoreColor
import CoreRaster
@testable import LibraryModel

/// Scans to a fixed result, or throws a fixed error.
private struct ScriptedDecoder: PhotoDecoding {
    var scan: FolderScan = FolderScan(candidates: [], failures: [])
    var error: LibraryError?
    func scan(folder: String) async throws -> FolderScan {
        if let error { throw error }
        return scan
    }
    func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage { throw LibraryError.missingFile(path) }
}

/// A clock that moves `step` each time the importer reads it; the callbacks
/// record the time they ran at.
private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private let step: Duration
    private var time: Duration = .zero
    private var progressCalls: [(Duration, ImportProgress)] = []
    private var batchList: [[PhotoItem]] = []
    init(step: Duration) { self.step = step }

    func tick() -> Duration { lock.withLock { time += step; return time } }
    func progress(_ value: ImportProgress) { lock.withLock { progressCalls.append((time, value)) } }
    func added(_ batch: [PhotoItem]) { lock.withLock { batchList.append(batch) } }
    var progresses: [(Duration, ImportProgress)] { lock.withLock { progressCalls } }
    var batches: [[PhotoItem]] { lock.withLock { batchList } }
}

/// 120 candidates in shuffled order, 3 of them known, plus 2 failures.
private func shoot() -> (scan: FolderScan, known: Set<String>) {
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    let candidates = (0..<120).map { i in
        ImportCandidate(path: "/Shots/day\(i % 3)/IMG_\(1000 + i).jpg",
                        captureDate: base.addingTimeInterval(Double((i * 37) % 120) * 60),
                        pixelSize: PixelSize(width: 4000, height: 3000), kind: .jpeg)
    }
    let failures = [FileFailure(path: "/Shots/broken.jpg", reason: "not an image file"),
                    FileFailure(path: "/Shots/bad.png", reason: "not an image file")]
    let known: Set<String> = [candidates[5].path, candidates[50].path, candidates[99].path]
    return (FolderScan(candidates: candidates.reversed(), failures: failures), known)
}

private func run(_ scan: FolderScan, known: Set<String>, step: Duration) async throws -> (ImportResult, Recorder) {
    let recorder = Recorder(step: step)
    let importer = LiveImporter(decoder: ScriptedDecoder(scan: scan), now: { recorder.tick() })
    let result = try await importer.importFolder("/Shots", known: known,
                                                 progress: { recorder.progress($0) }, added: { recorder.added($0) })
    return (result, recorder)
}

@Test func importsNewPhotosInCaptureOrderWithPathIDs() async throws {
    let (scan, known) = shoot()
    let (result, _) = try await run(scan, known: known, step: .milliseconds(7))
    #expect(result.added.count == 117)
    #expect(result.alreadyKnown == 3)
    #expect(result.failures == scan.failures)
    #expect(result.added.allSatisfy { !known.contains($0.id) })
    #expect(result.added.allSatisfy { $0.id == $0.path })
    let expected = scan.candidates.filter { !known.contains($0.path) }
        .sorted { ($0.captureDate, $0.path) < ($1.captureDate, $1.path) }
    #expect(result.added.map(\.id) == expected.map(\.path))
    #expect(result.added.map(\.captureDate) == expected.map(\.captureDate))
    let first = try #require(result.added.first)
    #expect(first.name == "IMG_1000")
    #expect(first.pixelSize == PixelSize(width: 4000, height: 3000))
    #expect(first.color == Color3(0.5, 0.5, 0.5))
}

@Test func batchesStayUnderFiftyAndRepeatTheResult() async throws {
    let (scan, known) = shoot()
    for step in [Duration.zero, .milliseconds(7), .milliseconds(300)] {
        let (result, recorder) = try await run(scan, known: known, step: step)
        #expect(recorder.batches.allSatisfy { !$0.isEmpty && $0.count <= 50 })
        #expect(recorder.batches.flatMap { $0 } == result.added)
    }
    // No time passes: the 50 cap alone splits the photos.
    let (_, still) = try await run(scan, known: known, step: .zero)
    #expect(still.batches.map(\.count) == [50, 50, 17])
    // 7 ms a photo: the 250 ms rule flushes before 50.
    let (_, timed) = try await run(scan, known: known, step: .milliseconds(7))
    #expect(timed.batches.count > 3)
}

@Test func progressIsThrottledAndEndsAtTotal() async throws {
    let (scan, known) = shoot()
    for step in [Duration.zero, .milliseconds(1), .milliseconds(20), .milliseconds(40)] {
        let (_, recorder) = try await run(scan, known: known, step: step)
        let calls = recorder.progresses
        #expect(calls.first?.1 == ImportProgress(done: 0, total: 117))
        #expect(calls.last?.1 == ImportProgress(done: 117, total: 117))
        let times = calls.map(\.0)
        for start in times {
            #expect(times.filter { $0 >= start && $0 < start + .seconds(1) }.count <= 30)
        }
    }
    let (_, steady) = try await run(scan, known: known, step: .milliseconds(20))
    #expect(steady.progresses.count > 10)
}

@Test func emptyFolderThrowsNoPhotos() async {
    let importer = LiveImporter(decoder: ScriptedDecoder(), now: { .zero })
    await #expect(throws: LibraryError.noPhotos("Empty")) {
        try await importer.importFolder("/Users/me/Empty/", known: [], progress: { _ in }, added: { _ in })
    }
}

@Test func onlyFailuresIsAResultNotAThrow() async throws {
    let failures = [FileFailure(path: "/F/broken.jpg", reason: "not an image file")]
    let (result, recorder) = try await run(FolderScan(candidates: [], failures: failures), known: [], step: .zero)
    #expect(result == ImportResult(added: [], alreadyKnown: 0, failures: failures))
    #expect(recorder.batches.isEmpty)
}

@Test func scanErrorsPassThrough() async {
    let importer = LiveImporter(decoder: ScriptedDecoder(error: .unreadableFolder("Shots")))
    await #expect(throws: LibraryError.unreadableFolder("Shots")) {
        try await importer.importFolder("/Shots", known: [], progress: { _ in }, added: { _ in })
    }
}

@Test func cancellationStopsAfterTheCurrentBatch() async throws {
    let (scan, known) = shoot()
    let recorder = Recorder(step: .zero)
    let importer = LiveImporter(decoder: ScriptedDecoder(scan: scan), now: { recorder.tick() })
    let result = try await importer.importFolder("/Shots", known: known, progress: { recorder.progress($0) }) { batch in
        recorder.added(batch)
        withUnsafeCurrentTask { $0?.cancel() }
    }
    #expect(result.added.count == 50)
    #expect(recorder.batches.map(\.count) == [50])
    #expect(recorder.progresses.last?.1 == ImportProgress(done: 50, total: 117))
}

@Test func liveImporterIsAvailable() {
    #expect(LiveImporter.unavailable == nil)
}
