// DesignFileRecentsTests.swift (#5215): Design's File > Open Recent ▸ and Open In ▸, the suite's
// SuiteFileCommands over DesignShell's documents bridge. A real Design window that opens a saved .design
// notes it in the suite's recents once; Open Recent then lists it, and choosing it sends one open hand-off
// to Design that DesignShell's host opens in a window. Open In stays off with its reason, since no other
// app reads a .design. Each test gets its own temp folder and a bridge on fake services
// (`DesignShell.bridgeOverride`). Nests in BodyCountSuites: hosted windows run one at a time. macOS only.
#if os(macOS)
import AppKit
import DesignModel
import Foundation
import SuiteModel
import SuiteShell
import SuiteUI
import Testing

@testable import DesignApp

/// FakeRecents that also records each event noted, in order.
private actor DesignNotedRecents: RecentWork {
    let inner = FakeRecents()
    private(set) var events: [RecentEvent] = []

    func list() async throws(SuiteError) -> RecentsList { try await inner.list() }
    func note(_ ref: SuiteDocumentRef, event: RecentEvent, at date: Date, thumbnail: String?) async throws(SuiteError) {
        events.append(event)
        try await inner.note(ref, event: event, at: date, thumbnail: thumbnail)
    }
    func remove(fileID: String) async throws(SuiteError) { try await inner.remove(fileID: fileID) }
    func clear(app: SuiteApp) async throws(SuiteError) { try await inner.clear(app: app) }
    func changes() async -> AsyncStream<Int> { await inner.changes() }
}

extension BodyCountSuites {
    @MainActor @Suite struct DesignFileRecentsTests {
        /// Logo.design, saved with one named page, in a new temp folder.
        private static func savedDesign() throws -> URL {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DesignRecents-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let page = DesignPage(id: "p1", name: "Recent Page", frameWidth: 800, frameHeight: 600)
            let url = folder.appendingPathComponent("Logo.design")
            try DesignWorkspace().services.filing.encode(DesignDocument(pages: [page])).write(to: url)
            return url
        }

        @Test(.timeLimit(.minutes(1))) func openRecentListsTheSavedFileAndChoosingItOpensIt() async throws {
            let recording = DesignNotedRecents()
            let handOffs = FakeHandOffs()
            var services = SuiteServices.fake()
            services.recents = recording
            services.sending = handOffs
            let bridge = SuiteDocumentsBridge(app: .design, services: services)
            DesignShell.bridgeOverride = bridge
            defer { DesignShell.bridgeOverride = nil }
            let url = try Self.savedDesign()
            let path = url.path(percentEncoded: false)

            let w = RenderBudgetWindow(DesignWindow(launch: DesignLaunch(file: url)))
            defer { w.close() }
            for _ in 0..<100 where await recording.events.isEmpty { try await Task.sleep(for: .milliseconds(50)) }
            #expect(await recording.events == [.opened], "the window's open never reached the bridge")

            let menu = SuiteFileMenu(app: .design, bridge: DesignShell.bridge)
            #expect(menu.recents.map(\.path) == [path], "File > Open Recent doesn't list the saved file")

            let recent = try #require(menu.recents.first)
            try await bridge.reopen(recent.fileID)
            let sent = await handOffs.sent
            #expect(sent.count == 1 && sent.first?.to == .design && sent.first?.verb == .open)
            #expect(sent.first?.documents.map(\.path) == [path])

            let queue = SuiteOpenQueue(windowID: DesignLaunch.windowID)
            #expect(try await DesignShell.host(opening: queue).accept(try #require(sent.first)) == .accepted)
            let appeared = queue.windowAppeared(requestWindow: {})
            let taken = try #require(appeared)
            var opened = DesignWorkspace()
            try opened.open(Data(contentsOf: taken), at: taken)
            #expect(opened.pages.map(\.name) == ["Recent Page"])
        }

        @Test func openInIsOffWithItsReason() throws {
            DesignShell.bridgeOverride = SuiteDocumentsBridge(app: .design, services: .fake())
            defer { DesignShell.bridgeOverride = nil }
            let url = try Self.savedDesign()
            var model = DesignWorkspace()
            try model.open(Data(contentsOf: url), at: url)

            let menu = SuiteFileMenu(app: .design, bridge: DesignShell.bridge, document: model.suiteDocument)
            #expect(model.suiteDocument?.path == url.path(percentEncoded: false))
            #expect(menu.openInTargets.isEmpty)
            #expect(menu.openInHelp == "No other app opens Design Document files.")
            #expect(SuiteFileMenu(app: .design, bridge: DesignShell.bridge, document: DesignWorkspace().suiteDocument)
                .openInHelp == SuiteFileMenu.openFirst)
        }
    }
}
#endif
