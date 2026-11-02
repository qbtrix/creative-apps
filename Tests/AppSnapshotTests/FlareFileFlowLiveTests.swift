// FlareFileFlowLiveTests.swift: file-flow FL-4 (packet flare/features/file-flow.md). The real Flare window,
// hosted on the render budget harness, notes each open and each save in the suite's shared recents through
// SuiteDocumentsBridge: opening Bounce.flare from Open Recent and saving it reach the bridge once each, in that
// order, with the file's path, and the workspace's file flow lists what the bridge lists (Flare keeps no list of
// its own, #5126); then Open In ▸ Halo on the saved animation sends one hand-off. Each test gets its
// own temp folder and a bridge on fake services (`FlareWindow.bridgeOverride`). Nests in BodyCountSuites: hosted
// windows run one at a time. macOS only.
#if os(macOS)
import AppKit
import FlareCore
import Foundation
import FlareModel
import SuiteModel
import SuiteShell
import SwiftUI
import Testing

@testable import FlareApp

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
    @MainActor @Suite struct FlareFileFlowLiveTests {
        /// Bounce.flare, the bounce sample, in a new temp folder.
        private static func bounce() throws -> URL {
            let folder = FileManager.default.temporaryDirectory.appending(path: "FlareFileFlowLive-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: "Bounce.flare")
            try FlareFormat.encode(FlareFixtures.bounce).write(to: url)
            return url
        }

        /// Waits up to 5 s for the recording to hold `count` events.
        private static func events(_ recording: NotedRecents, count: Int) async throws -> [RecentEvent] {
            for _ in 0..<100 where await recording.events.count < count { try await Task.sleep(for: .milliseconds(50)) }
            return await recording.events
        }

        @Test(.timeLimit(.minutes(1))) func anOpenAndASaveReachTheBridgeOnceEachAndOpenInSendsOne() async throws {
            let recording = NotedRecents()
            let handOffs = FakeHandOffs()
            var services = SuiteServices.fake()
            services.recents = recording
            services.sending = handOffs
            FlareWindow.bridgeOverride = SuiteDocumentsBridge(app: .flare, services: services)
            defer { FlareWindow.bridgeOverride = nil }
            let url = try Self.bounce()
            let w = RenderBudgetWindow(FlareWindow(model: FlareWorkspace(services: .fake())))
            defer { w.close() }
            try await w.settle()
            let perform = try #require(FlareWindow.shownPerform)

            perform(.file(.openRecent(path: url.path(percentEncoded: false))))
            #expect(try await Self.events(recording, count: 1) == [.opened], "the open never reached the bridge")
            try await w.settle()
            perform(.file(.save))
            #expect(try await Self.events(recording, count: 2) == [.opened, .saved], "the save never reached the bridge")
            try await w.settle()
            let path = url.path(percentEncoded: false)
            #expect(await recording.events == [.opened, .saved], "an event was noted twice")
            #expect(await recording.paths == [path, path])
            #expect(FlareWindow.bridge.recents(for: .flare).map(\.path) == [path])
            #expect(FlareWindow.shownModel?.recentFiles.map(\.path) == [path], "the file flow didn't get the bridge's list")

            let ref = try #require(FlareWindow.shownModel?.suiteDocument, "the saved animation has no suite ref")
            try await FlareWindow.bridge.openIn(ref, app: .halo)
            let sent = await handOffs.sent
            #expect(sent.count == 1, "Open In ▸ Halo didn't send exactly one hand-off")
            #expect(sent.first?.to == .halo && sent.first?.documents.map(\.path) == [path])
        }
    }
}
#endif
