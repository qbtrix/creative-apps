// SuiteDocumentsBridgeTests.swift: file-flow SF-7 (packet suite/features/file-flow.md). The bridge over the
// services' recents, routing and hand-offs: an open and a save note two events; `recents(for: .design)` lists
// only Design's files and drops one deleted from disk; `openIn` sends one hand-off with the verb open; Open In
// reads its targets and its refusal from the routing slot; reopening the app's own file goes to its document host,
// another app's to that app. Each test gets its own temp folder. macOS only.
#if os(macOS)
import Foundation
import SuiteModel
import Testing

@testable import SuiteShell

/// A temp folder with one empty file per name; returns each file's path.
private func files(_ names: [String]) throws -> [String] {
    let folder = FileManager.default.temporaryDirectory.appending(path: "BridgeTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return try names.map {
        let url = folder.appending(path: $0)
        try Data().write(to: url)
        return url.path(percentEncoded: false)
    }
}

private func ref(_ path: String, _ app: SuiteApp, _ type: SuiteTypeID) -> SuiteDocumentRef {
    SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: app, type: type,
                     displayName: URL(fileURLWithPath: path).lastPathComponent)
}

@MainActor struct SuiteDocumentsBridgeTests {
    @Test func anOpenAndASaveNoteTwoEvents() async throws {
        let services = SuiteServices.fake()
        let bridge = SuiteDocumentsBridge(app: .design, services: services)
        let paths = try files(["Poster.design"])
        let poster = ref(paths[0], .design, .designDocument)
        await bridge.note(poster, .opened)
        await bridge.note(poster, .saved)
        #expect(try await services.recents.list().revision == 2)
        #expect(bridge.recents(for: .design).map(\.name) == ["Poster.design"])
    }

    @Test func recentsListOnlyTheAppsFilesAndDropADeletedOne() async throws {
        let services = SuiteServices.fake()
        let bridge = SuiteDocumentsBridge(app: .design, services: services)
        let paths = try files(["Poster.design", "Logo.design", "Bounce.flare"])
        await bridge.note(ref(paths[0], .design, .designDocument), .opened)
        await bridge.note(ref(paths[1], .design, .designDocument), .saved)
        await bridge.note(ref(paths[2], .flare, .flareAnimation), .opened)
        #expect(Set(bridge.recents(for: .design).map(\.name)) == ["Poster.design", "Logo.design"])

        try FileManager.default.removeItem(atPath: paths[1])
        await bridge.refresh()
        #expect(bridge.recents(for: .design).map(\.name) == ["Poster.design"])
        #expect(try await services.recents.list().items.contains { $0.ref.displayName == "Logo.design" } == false)
        #expect(bridge.recents(for: .launcher).count == 2)
    }

    @Test func openInSendsOneHandOffWithTheVerbOpen() async throws {
        let services = SuiteServices.fake()
        let handOffs = try #require(services.sending as? FakeHandOffs)
        let bridge = SuiteDocumentsBridge(app: .design, services: services)
        let poster = ref(try files(["Poster.design"])[0], .design, .designDocument)
        try await bridge.openIn(poster, app: .halo)
        let sent = await handOffs.sent
        #expect(sent.count == 1)
        #expect(sent.first?.verb == .open)
        #expect(sent.first?.to == .halo)
        #expect(sent.first?.documents == [poster])
    }

    @Test func openInReadsItsTargetsAndRefusalFromRouting() throws {
        let bridge = SuiteDocumentsBridge(app: .design, services: .fake())
        let poster = ref(try files(["Poster.design"])[0], .design, .designDocument)
        let routing = FakeRouting()
        #expect(bridge.openInTargets(for: poster) == routing.openInTargets(for: .designDocument, from: .design))
        #expect(bridge.openInRefusal(for: poster) == routing.openInRefusal(for: .designDocument, from: .design))
        #expect(!bridge.openInTargets(for: poster).contains(.design))
    }

    @Test func reopeningTheAppsOwnFileGoesToItsHostNotLaunchServices() async throws {
        let services = SuiteServices.fake()
        let handOffs = try #require(services.sending as? FakeHandOffs)
        let bridge = SuiteDocumentsBridge(app: .design, services: services)
        let host = RecordingHost()
        bridge.host = host
        let paths = try files(["Poster.design", "Bounce.flare"])
        let poster = ref(paths[0], .design, .designDocument), bounce = ref(paths[1], .flare, .flareAnimation)
        await bridge.note(poster, .opened)
        await bridge.note(bounce, .opened)

        try await bridge.reopen(poster.fileID)
        #expect(await host.accepted.map(\.documents) == [[poster]], "Design's own file didn't reach Design's host")
        #expect(await host.accepted.first?.verb == .open)
        #expect(await handOffs.sent.isEmpty, "Design's own file went out through Launch Services")

        try await bridge.reopen(bounce.fileID)
        #expect(await handOffs.sent.map(\.to) == [.flare], "Flare's file didn't go to Flare")
        #expect(await host.accepted.count == 1)
    }
}

/// A document host that accepts every hand-off and keeps each one.
private actor RecordingHost: SuiteDocumentHost {
    private(set) var accepted: [HandOff] = []
    func refusal(for handOff: HandOff) async -> SuiteError? { nil }
    func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState {
        accepted.append(handOff)
        return .accepted
    }
}
#endif
