// LibraryFileFlowLiveTests.swift: file-flow LF-4 (packet library/features/file-flow.md). The real Library window,
// hosted on the render budget harness, on the `samples` fixture: a dropped PNG imports and a dropped .halo goes to
// Halo as one hand-off through SuiteDocumentsBridge; opening the PNG in the loupe notes it in the suite's shared
// recents once, however often the window looks, and the catalog's Recent Files then read the suite list; the loupe
// drags its photo out as the file URL and a PNG. Each test gets its own temp folder and a bridge on fake services
// (`LibraryWindow.bridgeOverride`). Nests in BodyCountSuites: hosted windows run one at a time. macOS only.
#if os(macOS)
import AppKit
import Foundation
import LibraryModel
import SuiteKernel
import SuiteModel
import SwiftUI
import Testing

@testable import LibraryApp
@testable import SuiteShell

/// FakeRecents that also records each event noted and its path, in order.
private actor NotedRecents: RecentWork {
    let inner = FakeRecents()
    private(set) var events: [RecentEvent] = []
    private(set) var paths: [String] = []

    func list() async throws(SuiteError) -> RecentsList { try await inner.list() }
    func note(_ ref: SuiteDocumentRef, event: RecentEvent, at date: Date, thumbnail: String?) async throws(SuiteError) {
        events.append(event)
        paths.append(ref.path)
        try await inner.note(ref, event: event, at: date, thumbnail: thumbnail)
    }
    func remove(fileID: String) async throws(SuiteError) { try await inner.remove(fileID: fileID) }
    func clear(app: SuiteApp) async throws(SuiteError) { try await inner.clear(app: app) }
    func changes() async -> AsyncStream<Int> { await inner.changes() }
}

extension BodyCountSuites {
    @MainActor @Suite struct LibraryFileFlowLiveTests {
        /// A real 8 x 6 PNG, Shot.png, in a new temp folder.
        private static func shot() throws -> URL {
            let folder = FileManager.default.temporaryDirectory.appending(path: "LibraryFileFlowLive-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let context = try #require(CGContext(
                data: nil, width: 8, height: 6, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(CGColor(srgbRed: 0.2, green: 0.5, blue: 0.8, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 6))
            let image = try #require(context.makeImage())
            let url = folder.appending(path: "Shot.png")
            try SuiteImageIO.encode(image, as: .png, quality: nil).write(to: url)
            return url
        }

        /// Polls up to 5 s until `done` holds.
        private static func until(_ done: () async -> Bool) async throws {
            for _ in 0..<100 where !(await done()) { try await Task.sleep(for: .milliseconds(50)) }
        }

        @Test(.timeLimit(.minutes(1))) func aDropHandsOffAndALoupeOpenIsNotedOnceAndDragsOut() async throws {
            let recording = NotedRecents()
            let handOffs = FakeHandOffs()
            var services = SuiteServices.fake()
            services.recents = recording
            services.sending = handOffs
            LibraryWindow.bridgeOverride = SuiteDocumentsBridge(app: .library, services: services)
            defer { LibraryWindow.bridgeOverride = nil }
            let url = try Self.shot()
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let path = url.path(percentEncoded: false)
            let halo = url.deletingLastPathComponent().appending(path: "Intro.halo").path(percentEncoded: false)
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "samples"]))
            defer { w.close() }
            try await w.settle(800)

            // The drop: the PNG imports, the .halo goes to Halo.
            let drop = try #require(LibraryWindow.shownDrop)
            drop([.place(path: path), .handOff(path: halo, app: "halo")])
            try await Self.until { await !handOffs.sent.isEmpty }
            let sent = await handOffs.sent
            #expect(sent.count == 1 && sent.first?.to == .halo && sent.first?.documents.map(\.path) == [halo],
                    "the dropped .halo didn't reach Halo exactly once")
            try await w.settle()
            #expect(LibraryWindow.shownModel?.items.contains { $0.path == path } == true, "the dropped PNG wasn't imported")

            // The loupe open: noted once, then the catalog's Recent Files read the suite list.
            let open = try #require(LibraryWindow.shownOpen)
            open(path)
            try await Self.until { await !recording.events.isEmpty }
            try await w.settle()
            open(path)
            try await w.settle()
            #expect(await recording.events == [.opened], "the loupe open wasn't noted exactly once")
            #expect(await recording.paths == [path])
            #expect(LibraryWindow.bridge.recents(for: .library).map(\.path) == [path])
            try await Self.until { LibraryWindow.shownModel?.recentFiles.isEmpty == false }
            #expect(LibraryWindow.shownModel?.recentFiles.map(\.path) == [path], "Recent Files don't read the suite list")

            // The drag-out: the file URL and a PNG of the photo.
            let items = try #require(LibraryWindow.shownDragItems)()
            #expect(items.count == 2, "the loupe drags the file and a PNG")
            if case .image(_, let width, let height)? = items.last { #expect(width == 8 && height == 6) }
            let types = SuiteDragSource.provider(for: items, coding: SuitePasteboardCoding()).registeredTypeIdentifiers
            #expect(types.contains(SuiteTypeID.fileURL.rawValue) && types.contains(SuiteTypeID.png.rawValue))
        }
    }
}
#endif
