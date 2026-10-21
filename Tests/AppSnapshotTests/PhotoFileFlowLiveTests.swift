// PhotoFileFlowLiveTests.swift: file-flow PF-4 (packet photo/features/file-flow.md). The real Photo window,
// hosted on the render budget harness, notes each open and each save in the suite's shared recents through
// SuiteDocumentsBridge: opening beach.png and saving it reach the bridge once each, in that order, with the
// file's path and Photo as the app. PF-3's half, Photo's old Open Recent list imported once and its key
// removed, is written here and disabled until PF-2 retires the key. Each test gets its own temp folder and a bridge on
// fake services. Nests in BodyCountSuites: hosted windows run one at a time. macOS only.
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

/// FakeRecents that also records each event noted and its path, in order.
private actor RecordingRecents: RecentWork {
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
    @MainActor @Suite struct PhotoFileFlowLiveTests {
        /// A bridge for Photo whose recents record every note.
        private static func bridge() -> (SuiteDocumentsBridge, RecordingRecents) {
            let recording = RecordingRecents()
            var services = SuiteServices.fake()
            services.recents = recording
            return (SuiteDocumentsBridge(app: .photo, services: services), recording)
        }

        /// beach.png, a 4 x 3 white PNG, in a new temp folder.
        private static func beach() throws -> URL {
            let folder = FileManager.default.temporaryDirectory.appending(path: "PhotoFileFlowLive-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
            let url = folder.appending(path: "beach.png")
            try ImageIOCodec().encode(white, as: .png, quality: 1).write(to: url)
            return url
        }

        /// Waits up to 5 s for the recording to hold `count` events.
        private static func events(_ recording: RecordingRecents, count: Int) async throws -> [RecentEvent] {
            for _ in 0..<100 where await recording.events.count < count { try await Task.sleep(for: .milliseconds(50)) }
            return await recording.events
        }

        @Test(.timeLimit(.minutes(1))) func anOpenAndASaveReachTheBridgeOnceEach() async throws {
            let (bridge, recording) = Self.bridge()
            let url = try Self.beach()
            let w = RenderBudgetWindow(PhotoWindow(model: PhotoWorkspace(services: .fake)))
            defer { w.close() }
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let files = try #require(edited.files)
            files.bridge = bridge
            let send = try #require(edited.send)

            send(.openFile(url))
            #expect(try await Self.events(recording, count: 1) == [.opened], "the open never reached the bridge")
            #expect(await edited.save(), "Save didn't land")
            #expect(try await Self.events(recording, count: 2) == [.opened, .saved])
            try await w.settle()
            let path = url.path(percentEncoded: false)
            #expect(await recording.events == [.opened, .saved], "an event was noted twice")
            #expect(await recording.paths == [path, path])
            #expect(bridge.recents(for: .photo).map(\.path) == [path])
        }

        @Test(.disabled("waits on PF-2: the old key stays until the window switches over"), .timeLimit(.minutes(1)))
        func theOldListIsImportedOnceAndItsKeyRemoved() async throws {
            let old = try Self.beach().path(percentEncoded: false)
            UserDefaults.standard.set([old], forKey: "PhotoRecentFiles")
            defer { UserDefaults.standard.removeObject(forKey: "PhotoRecentFiles") }
            let (bridge, recording) = Self.bridge()
            let w = RenderBudgetWindow(PhotoWindow(model: PhotoWorkspace(services: .fake)))
            defer { w.close() }
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let files = try #require(edited.files)
            files.bridge = bridge
            let send = try #require(edited.send)
            send(.openFile(try Self.beach()))
            _ = try await Self.events(recording, count: 2)
            #expect(UserDefaults.standard.stringArray(forKey: "PhotoRecentFiles") == nil, "the old list's key stayed")
            #expect(await recording.paths.filter { $0 == old }.count == 1, "the old list wasn't imported exactly once")
        }
    }
}
#endif
