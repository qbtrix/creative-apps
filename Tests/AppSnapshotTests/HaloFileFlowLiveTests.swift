// HaloFileFlowLiveTests.swift: file-flow HF-4 (packet halo/features/file-flow.md). The real Halo window,
// hosted on the render budget harness, notes each open and each save in the suite's shared recents through
// SuiteDocumentsBridge: opening Keyed.halo from Open Recent and saving it reach the bridge once each, in that
// order, with the file's path, and the project's file flow then lists it; a Clear Menu the file-flow commands
// leave for the window empties Halo's part of the list. Each test gets its own temp folder and a bridge on fake
// services (`HaloWindow.bridgeOverride`). Nests in BodyCountSuites: hosted windows run one at a time. macOS only.
#if os(macOS)
import AppKit
import Foundation
import HaloModel
import SuiteModel
import SuiteShell
import SwiftUI
import Testing

@testable import HaloApp

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
    @MainActor @Suite struct HaloFileFlowLiveTests {
        /// Keyed.halo, the keyed sample, in a new temp folder.
        private static func keyed() throws -> URL {
            let folder = FileManager.default.temporaryDirectory.appending(path: "HaloFileFlowLive-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: "Keyed.halo")
            try HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project().fileData().write(to: url)
            return url
        }

        /// Waits up to 5 s for `done`.
        private static func wait(_ done: () async -> Bool) async throws {
            for _ in 0..<100 where !(await done()) { try await Task.sleep(for: .milliseconds(50)) }
        }

        @Test(.timeLimit(.minutes(1))) func anOpenAndASaveReachTheBridgeOnceEach() async throws {
            UserDefaults.standard.removeObject(forKey: "HaloRecentFiles")
            let recording = NotedRecents()
            var services = SuiteServices.fake()
            services.recents = recording
            HaloWindow.bridgeOverride = SuiteDocumentsBridge(app: .halo, services: services)
            defer { HaloWindow.bridgeOverride = nil }
            let url = try Self.keyed()
            let path = url.path(percentEncoded: false)
            let w = RenderBudgetWindow(HaloWindow(model: HaloProject(services: .live)))
            defer { w.close() }
            try await w.settle()
            let perform = try #require(HaloWindow.shownPerform)

            perform(.openRecent(path))
            try await Self.wait { await recording.events.count >= 1 }
            #expect(await recording.events == [.opened], "the open never reached the bridge")
            try await w.settle()
            perform(.save)
            try await Self.wait { await recording.events.count >= 2 }
            try await w.settle()
            #expect(await recording.events == [.opened, .saved], "an event was lost or noted twice")
            #expect(await recording.paths == [path, path])
            #expect(HaloWindow.shownProject?.recentFiles.map(\.path) == [path], "the project never listed the file")
        }

        @Test(.timeLimit(.minutes(1))) func aClearMenuLeftForTheWindowEmptiesHalosRecents() async throws {
            let bridge = SuiteDocumentsBridge(app: .halo, services: .fake())
            HaloWindow.bridgeOverride = bridge
            defer { HaloWindow.bridgeOverride = nil }
            let url = try Self.keyed()
            let path = url.path(percentEncoded: false)
            await bridge.note(SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .halo,
                                               type: .haloProject, displayName: "Keyed.halo"), .opened)
            #expect(bridge.recents(for: .halo).map(\.path) == [path])
            var project = HaloProject(services: .live)
            try project.clearRecent()
            let w = RenderBudgetWindow(HaloWindow(model: project))
            defer { w.close() }
            try await Self.wait { bridge.recents(for: .halo).isEmpty }
            #expect(bridge.recents(for: .halo).isEmpty, "Clear Menu never reached the bridge")
        }
    }
}
#endif
