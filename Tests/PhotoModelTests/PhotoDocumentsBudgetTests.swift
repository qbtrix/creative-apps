// PhotoDocumentsBudgetTests.swift: photo-documents' budgets (blueprint 7.1,
// packet D-5) on the `large` fixture (4000 x 3000, three layers) with one
// cheap edit, so the image is dirty and an autosave writes, through
// LiveArchive, PhotoZip and RawCodec, the lossless in-memory codec the
// round-trip tests use (the app's image codec isn't on Linux). PB-18: Save,
// `snapshot()` plus the archive encode plus the OpenRaster container, within
// 2 s. PB-19: Open of that file, unzipping plus `openDocument`, within 2 s.
// PB-20: an autosave's off-main part, `recoveryEntry` plus a LiveRecovery
// write into a temporary folder, within 2 s; and its main-actor part, copying
// the PhotoWorkspace value (copy-on-write: no pixel is converted), within
// 1.6 ms in release and 16 ms in debug. The copy touches no pixels, so it is
// gated in both builds. The rest convert every pixel and cost minutes each in
// debug, so they run, gated, only in a release build (`swift test -c release
// -Xswiftc -enable-testing --filter PhotoDocumentsBudgetTests`, which
// `@testable` needs) and are skipped in debug, which is what CI runs. Each is
// timed once. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import Testing

#if DEBUG
/// Debug skips the whole-document passes; it gates only the copy.
private let releaseBuild = false
/// The main-actor copy's bound in debug.
private let copyBudget = Duration.milliseconds(16)
#else
private let releaseBuild = true
/// The main-actor copy's bound in release.
private let copyBudget = Duration.microseconds(1600)
#endif

/// The whole-document passes' bound (PB-18, PB-19, PB-20 off main).
private let passBudget = Duration.seconds(2)

@Suite struct PhotoDocumentsBudgetTests {
    private let archive = LiveArchive()
    private let clock = ContinuousClock()

    /// The `large` fixture, edited once so it reads dirty.
    private func document() throws -> PhotoWorkspace {
        var workspace = try PhotoWorkspace.fixture(.large)
        let top = try #require(workspace.layers.first?.id)
        workspace.setOpacity(top, percent: 80)
        #expect(workspace.layers.map(\.name) == ["Noise", "Gradient", "Background"])
        #expect(workspace.isDirty)
        return workspace
    }

    @Test(.enabled(if: releaseBuild, "whole-document passes run in release only"))
    func saveDocument() throws {
        let workspace = try document()
        var file = Data()
        let cost = try clock.measure {
            file = try archive.container(try archive.encode(try workspace.snapshot(), codec: RawCodec()))
        }
        #expect(file.count > 3 * 4000 * 3000 * 4, "three 12 MP layers written")
        check("PB-18 save", cost, within: passBudget)
    }

    @Test(.enabled(if: releaseBuild, "whole-document passes run in release only"))
    func openDocument() throws {
        let original = try document()
        let file = try archive.container(try archive.encode(try original.snapshot(), codec: RawCodec()))
        var opened = PhotoWorkspace(services: .fake)
        let cost = try clock.measure {
            try opened.openDocument(try archive.package(fromContainer: file), name: "large.ora", archive: archive,
                                    codec: RawCodec())
        }
        #expect(opened.layers.map(\.name) == original.layers.map(\.name))
        #expect(opened.canvas == CanvasSize(width: 4000, height: 3000))
        #expect(!opened.isDirty)
        check("PB-19 open", cost, within: passBudget)
    }

    @Test func autosaveSnapshotCopy() throws {
        let workspace = try document()
        var copy = PhotoWorkspace(services: .fake)
        let copyCost = clock.measure { copy = workspace }
        #expect(copy.layers == workspace.layers && copy.isDirty)
        check("PB-20 workspace copy", copyCost, within: copyBudget)
        guard releaseBuild else { return }

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoDocumentsBudgetTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LiveRecovery(directory: folder)
        var wrote = false
        let writeCost = try clock.measure {
            if let entry = try copy.recoveryEntry(now: 100, archive: archive, codec: RawCodec()) {
                try store.write(entry, window: "budget")
                wrote = true
            }
        }
        #expect(wrote, "a dirty image has an entry to write")
        #expect(FileManager.default.fileExists(atPath: store.file(for: "budget").path))
        check("PB-20 autosave write", writeCost, within: passBudget)
    }

    /// Prints the one timed call and holds it to `budget`.
    private func check(_ name: String, _ cost: Duration, within budget: Duration) {
        print("PhotoBudget \(name) \(ms(cost)) ms (1 event, gated)")
        #expect(cost <= budget, "\(name): \(cost)")
    }
}

private func ms(_ duration: Duration) -> Double { (duration / .milliseconds(1) * 10_000).rounded() / 10_000 }
