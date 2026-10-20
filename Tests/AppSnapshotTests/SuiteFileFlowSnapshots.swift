// SuiteFileFlowSnapshots.swift (file-flow SF-4): suite-open-recent (the week's files newest first, then
// Clear Menu), suite-open-in-off (Open In off with its sentence), suite-drop-mark-open ("Open in Halo") and
// suite-drop-mark-refuse (the .xyz refusal), each -light and -dark. AppKit can't draw an open NSMenu
// offscreen, so the menu images lay out what SuiteFileMenu gives the menu under its title. macOS only.
#if os(macOS)
import Foundation
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import SuiteShell

@MainActor
@Suite struct SuiteFileFlowSnapshots {
    private static let week = SuiteFixtures.weekOfWorkFiles

    @Test func menusAndMarks() async throws {
        let tick = MinuteClock()
        let bridge = SuiteDocumentsBridge(app: .launcher, services: .fake(), now: { tick.next() }, exists: { _ in true })
        for (name, app, type) in Self.week.reversed() {
            let path = "/tmp/FileFlowSnapshots/\(name)"
            await bridge.note(SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: app,
                                               type: type, displayName: name), .opened)
        }
        let menu = SuiteFileMenu(app: .launcher, bridge: bridge)
        #expect(menu.recents.map(\.name) == Self.week.map(\.0), "Open Recent isn't the week's files newest first")
        let halo: [DropAction] = [.handOff(path: "/tmp/Intro.halo", app: "halo")]
        let xyz: [DropAction] = [.refuse(path: "/tmp/notes.xyz", reason: "AfterGlow can't open .xyz files.")]
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(FileFlowStage { RecentList(menu: menu) }, name: "suite-open-recent-\(scheme.name)", scheme: scheme)
            try snapshot(FileFlowStage { OpenInOff(menu: menu) }, name: "suite-open-in-off-\(scheme.name)", scheme: scheme)
            try snapshot(FileFlowStage { Self.mark(halo) }, name: "suite-drop-mark-open-\(scheme.name)", scheme: scheme)
            try snapshot(FileFlowStage { Self.mark(xyz) }, name: "suite-drop-mark-refuse-\(scheme.name)", scheme: scheme)
        }
    }

    private static func mark(_ actions: [DropAction]) -> SuiteDropMarkView {
        SuiteDropMarkView(sentence: SuiteDropMark.sentence(for: actions, app: .launcher) ?? "",
                          refused: SuiteDropMark.refuses(actions))
    }
}

/// A clock a minute later at each read, so the notes keep their order.
private final class MinuteClock: @unchecked Sendable {
    private let lock = NSLock()
    private var minutes = 0.0

    func next() -> Date {
        lock.withLock {
            minutes += 1
            return Date(timeIntervalSinceReferenceDate: 800_000_000 + minutes * 60)
        }
    }
}

/// Open Recent ▸'s items as the menu shows them.
private struct RecentList: View {
    let menu: SuiteFileMenu

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Open Recent").font(SuiteFont.headline)
            ForEach(menu.recents, id: \.fileID) { file in
                Button(file.name) {}.buttonStyle(.borderless)
            }
            Divider()
            Button("Clear Menu") {}.buttonStyle(.borderless)
        }
        .padding(SuiteSpacing.l)
        .fixedSize()
    }
}

/// Open In ▸ off, with the sentence its help gives.
private struct OpenInOff: View {
    let menu: SuiteFileMenu

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Button("Open In") {}.buttonStyle(.borderless).disabled(menu.openInTargets.isEmpty)
            Text(menu.openInHelp ?? "").font(SuiteFont.caption).foregroundStyle(.secondary)
        }
        .padding(SuiteSpacing.l)
        .fixedSize()
    }
}

/// One file-flow view on a panel at the top left of the 1440x900 frame.
private struct FileFlowStage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif
