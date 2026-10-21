// LibraryExportBatchTests.swift: EX-13's cancel and retry (packet
// docs/blueprints/library/features/export.md, slice EX-e), written by EX-12
// before its code and enabled by EX-13. Cancel is pressed from inside the
// run (progress or render) by cancelling the runner's own task, so each is exact;
// that task is a child `Task`, so the test's own task is never cancelled.
import Foundation
import Testing

@testable import LibraryModel

/// Fails `render` for the photo ids in `failing`; every other photo renders on the fake.
private struct SomeFailExporter: PhotoExporting {
    let failing: Set<String>
    func plan(_ photos: [PhotoItem], options: ExportOptions, existingNames: Set<String>) -> ExportPlan {
        FakeExporter().plan(photos, options: options, existingNames: existingNames)
    }
    func render(_ item: ExportPlan.Item, photo: PhotoItem) async throws -> DisplayImage {
        if failing.contains(photo.id) { throw LibraryError.renderFailed("broken on purpose") }
        return try await FakeExporter().render(item, photo: photo)
    }
}

/// The photo ids the exporter was asked to render, in order.
private actor RenderLog {
    private(set) var ids: [String] = []
    func add(_ id: String) { ids.append(id) }
}

/// Renders on the fake and logs each photo it renders.
private struct LoggingExporter: PhotoExporting {
    let log: RenderLog
    func plan(_ photos: [PhotoItem], options: ExportOptions, existingNames: Set<String>) -> ExportPlan {
        FakeExporter().plan(photos, options: options, existingNames: existingNames)
    }
    func render(_ item: ExportPlan.Item, photo: PhotoItem) async throws -> DisplayImage {
        await log.add(photo.id)
        return try await FakeExporter().render(item, photo: photo)
    }
}

/// Renders on the fake, then presses Cancel (cancels the runner's task) while rendering `cancelling`.
private struct CancelInRenderExporter: PhotoExporting {
    let cancelling: String
    func plan(_ photos: [PhotoItem], options: ExportOptions, existingNames: Set<String>) -> ExportPlan {
        FakeExporter().plan(photos, options: options, existingNames: existingNames)
    }
    func render(_ item: ExportPlan.Item, photo: PhotoItem) async throws -> DisplayImage {
        let image = try await FakeExporter().render(item, photo: photo)
        if photo.id == cancelling { withUnsafeCurrentTask { $0?.cancel() } }
        return image
    }
}

@Suite struct LibraryExportBatchTests {
    func id(_ name: String) -> String { "/fixture/shoot/\(name).jpg" }
    func shoot(selecting count: Int) -> LibraryCatalog {
        let photos = LibraryFixtures.photos(named: "shoot")
        var catalog = LibraryCatalog(services: .fake(photos))
        catalog.load(photos)
        catalog.setSort(.name)
        catalog.select(Set(catalog.order.prefix(count)))
        return catalog
    }
    func byID(_ catalog: LibraryCatalog) -> [String: PhotoItem] {
        Dictionary(uniqueKeysWithValues: catalog.exportTargets.map { ($0.id, $0) })
    }

    @Test func cancelBeforeTheSecondPhotoStopsAfterOneWrite() async throws {
        var catalog = shoot(selecting: 24)
        #expect(catalog.beginExport(folder: "/out") == true)
        let planned = catalog.exportPlan(existingNames: [])
        let plan = try #require(planned)
        #expect(plan.items.count == 24)
        let writer = FakeJPEGWriter()
        let log = RenderLog()
        let photos = byID(catalog)
        let summary = await Task {
            await ExportRunner.run(
                plan, photos: photos, exporter: LoggingExporter(log: log), writer: writer,
                writeSidecar: { _, _, _ in },
                progress: { done in if done == 1 { withUnsafeCurrentTask { $0?.cancel() } } })
        }.value
        #expect(await log.ids == [id("IMG_0001")], "the 2nd photo was rendered after Cancel")
        #expect(summary.cancelled)
        #expect(summary.written == ["IMG_0001.jpg"])
        #expect(summary.message == "Exported 1 of 24. Export was cancelled.")
        #expect(try await writer.existingNames(in: "/out") == ["IMG_0001.jpg"])
    }

    @Test func cancelDuringARenderWritesNothingForThatPhoto() async throws {
        var catalog = shoot(selecting: 3)
        #expect(catalog.beginExport(folder: "/out") == true)
        let planned = catalog.exportPlan(existingNames: [])
        let plan = try #require(planned)
        let writer = FakeJPEGWriter()
        let (photos, cancelling) = (byID(catalog), id("IMG_0002"))
        let summary = await Task {
            await ExportRunner.run(
                plan, photos: photos, exporter: CancelInRenderExporter(cancelling: cancelling),
                writer: writer, writeSidecar: { _, _, _ in }, progress: { _ in })
        }.value
        #expect(summary.cancelled)
        #expect(summary.written == ["IMG_0001.jpg"])
        #expect(summary.message == "Exported 1 of 3. Export was cancelled.")
        #expect(try await writer.existingNames(in: "/out") == ["IMG_0001.jpg"])
    }

    @Test func retryPlansOnlyTheFailedPhotosUnderTheGivenOptions() async throws {
        var catalog = shoot(selecting: 5)
        #expect(catalog.beginExport(folder: "/out") == true)
        let planned = catalog.exportPlan(existingNames: [])
        let plan = try #require(planned)
        let failing: Set = [id("IMG_0002"), id("IMG_0004")]
        let summary = await ExportRunner.run(
            plan, photos: byID(catalog), exporter: SomeFailExporter(failing: failing), writer: FakeJPEGWriter(),
            writeSidecar: { _, _, _ in }, progress: { _ in })
        #expect(summary.failedIDs == [id("IMG_0002"), id("IMG_0004")])
        #expect(summary.written == ["IMG_0001.jpg", "IMG_0003.jpg", "IMG_0005.jpg"])
        #expect(summary.failures.map(\.path) == ["IMG_0002.jpg", "IMG_0004.jpg"])
        #expect(!summary.cancelled)
        #expect(summary.message == "2 photos couldn't be exported.")
        catalog.finishExport(summary)
        let options = ExportOptions(longEdge: 1024, quality: 70, folder: "/elsewhere")
        let retried = catalog.retryExport(options: options, existingNames: ["IMG_0002.jpg"])
        let retry = try #require(retried)
        #expect(retry.items.map(\.photoID) == [id("IMG_0002"), id("IMG_0004")])
        #expect(retry.items.map(\.fileName) == ["IMG_0002 2.jpg", "IMG_0004.jpg"])
        #expect(retry.options == options)
        #expect(catalog.exportState == .running(done: 0, total: 2))
    }

    @Test func retryRefusesWithoutFailures() {
        var catalog = shoot(selecting: 2)
        let options = ExportOptions(folder: "/out")
        #expect(catalog.retryExport(options: options, existingNames: []) == nil)
        catalog.finishExport(ExportSummary(total: 2, written: ["IMG_0001.jpg", "IMG_0002.jpg"]))
        #expect(catalog.exportState == .idle)
        #expect(catalog.beginExport(folder: "/out") == true)
        _ = catalog.exportPlan(existingNames: [])
        catalog.finishExport(ExportSummary(total: 2, written: ["IMG_0001.jpg", "IMG_0002.jpg"]))
        #expect(catalog.retryExport(options: options, existingNames: []) == nil)
        #expect(catalog.exportState == .finished(ExportSummary(total: 2, written: ["IMG_0001.jpg", "IMG_0002.jpg"])))
    }

    @Test func cancelExportIsTrueOnlyWhileRunning() {
        var catalog = shoot(selecting: 2)
        #expect(catalog.cancelExport() == false)
        #expect(catalog.beginExport(folder: "/out") == true)
        #expect(catalog.cancelExport() == false)
        _ = catalog.exportPlan(existingNames: [])
        #expect(catalog.cancelExport() == true)
        catalog.finishExport(ExportSummary(total: 2, written: ["IMG_0001.jpg"], cancelled: true))
        #expect(catalog.cancelExport() == false)
    }
}
