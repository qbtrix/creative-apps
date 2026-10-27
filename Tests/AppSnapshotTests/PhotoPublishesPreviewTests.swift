// PhotoPublishesPreviewTests.swift: shared-thumbnails ST-7 (packet
// suiteui/features/shared-thumbnails.md). The real Photo window, hosted on the
// render budget harness, publishes the saved document's thumbnail to the
// suite's previews after each save that lands: once per save, under the
// file's path, off the main thread, and before Save reports done. A save that
// fails publishes nothing. The window publishes through the thumbnails its
// documents bridge holds, never a store of its own. It runs on fake services
// with the live archive (the fake writes no thumbnail) and a fake bridge whose
// thumbnails are a recording store, so nothing reaches the real support
// folder. Nests in BodyCountSuites: hosted windows run one at a time. macOS
// only.
#if os(macOS)
import AppKit
import CoreRaster
import Foundation
import PhotoModel
import SuiteModel
import SuiteShell
import SwiftUI
import Testing

@testable import PhotoApp

/// A ThumbnailPublishing that records each publish: its path, its bytes and whether it ran on the main thread.
private final class RecordingThumbnails: ThumbnailPublishing, @unchecked Sendable {
    private let lock = NSLock()
    private var published: [(path: String, png: Data, onMain: Bool)] = []

    var paths: [String] { lock.withLock { published.map(\.path) } }
    var pngs: [Data] { lock.withLock { published.map(\.png) } }
    var onMain: [Bool] { lock.withLock { published.map(\.onMain) } }

    private static func isMain() -> Bool { Thread.isMainThread }

    func publish(png: Data, for ref: SuiteDocumentRef) async throws(SuiteError) -> String {
        let main = Self.isMain()
        lock.withLock { published.append((ref.path, png, main)) }
        return "thumbnails/\(SuiteDocumentRef.fileKey(ref.fileID)).png"
    }

    func preview(for ref: SuiteDocumentRef) async -> Data? { nil }
}

extension BodyCountSuites {
    @MainActor @Suite struct PhotoPublishesPreviewTests {
        /// Beach.ora, a one-layer 4 x 3 white document, in a new temp folder.
        private static func beach() throws -> URL {
            let folder = FileManager.default.temporaryDirectory.appending(path: "PhotoPublishesPreview-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
            let snapshot = PhotoDocumentSnapshot(canvas: CanvasSize(width: 4, height: 3),
                                                 layers: [PhotoLayer(id: "base", name: "Background")],
                                                 pixels: ["base": white])
            let archive = PhotoServices.live.archive
            let url = folder.appending(path: "Beach.ora")
            try archive.container(try archive.encode(snapshot, codec: ImageIOCodec())).write(to: url)
            return url
        }

        /// The window on fake services with the live archive, `url` open, its saves publishing to `thumbnails`.
        private static func open(_ url: URL, _ thumbnails: RecordingThumbnails) async throws
            -> (RenderBudgetWindow<PhotoWindow>, PhotoWindowEditedView) {
            var services = PhotoServices.fake
            services.archive = PhotoServices.live.archive
            let w = RenderBudgetWindow(PhotoWindow(model: PhotoWorkspace(services: services)))
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let files = try #require(edited.files)
            var suite = SuiteServices.fake()
            suite.thumbnails = thumbnails
            files.bridge = SuiteDocumentsBridge(app: .photo, services: suite)
            let send = try #require(edited.send)
            send(.openFile(url))
            for _ in 0..<100 where edited.workspace?.documentName != url.lastPathComponent || files.working != nil {
                try await Task.sleep(for: .milliseconds(50))
            }
            #expect(edited.workspace?.documentName == url.lastPathComponent, "Beach.ora didn't open")
            return (w, edited)
        }

        @Test(.timeLimit(.minutes(1))) func aSaveIsPublishedOnceUnderItsPathBeforeItReportsDone() async throws {
            let url = try Self.beach()
            let thumbnails = RecordingThumbnails()
            let (w, edited) = try await Self.open(url, thumbnails)
            defer { w.close() }
            #expect(thumbnails.paths.isEmpty, "an open published a preview")
            #expect(await edited.save(), "Save didn't land")
            #expect(thumbnails.paths == [url.path(percentEncoded: false)], "the save wasn't published once before Save was done")
            try await w.settle()
            #expect(thumbnails.paths.count == 1, "one save published more than once")
            let saved = try PhotoServices.live.archive.package(fromContainer: Data(contentsOf: url))
            #expect(thumbnails.pngs.first == saved.files[PhotoSavedPreview.entry], "the preview isn't the saved file's thumbnail")
        }

        @Test(.timeLimit(.minutes(1))) func offMain() async throws {
            let thumbnails = RecordingThumbnails()
            let (w, edited) = try await Self.open(try Self.beach(), thumbnails)
            defer { w.close() }
            #expect(await edited.save(), "Save didn't land")
            #expect(thumbnails.onMain == [false], "the preview was published on the main thread")
        }

        @Test(.timeLimit(.minutes(1))) func aFailedSavePublishesNothing() async throws {
            let url = try Self.beach()
            let thumbnails = RecordingThumbnails()
            let (w, edited) = try await Self.open(url, thumbnails)
            defer { w.close() }
            try FileManager.default.removeItem(at: url.deletingLastPathComponent())
            #expect(!(await edited.save()), "a save into a folder that's gone landed")
            #expect(edited.files?.saveFailed == true)
            try await w.settle()
            #expect(thumbnails.paths.isEmpty, "a failed save published a preview")
        }
    }
}
#endif
