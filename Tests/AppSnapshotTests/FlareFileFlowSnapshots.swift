// FlareFileFlowSnapshots.swift (file-flow FL-2's test, FL-5's file): Flare's File menu as the suite renders
// it for Flare. flare-open-recent-{light,dark}: Open Recent ▸ and Open In ▸ as SuiteFileCommands gives them
// for `.flare` with Bounce.flare open and in the suite's recents: the file listed, Clear Menu under it, and
// Open In off with its reason, since no other app reads a .flare yet (flare-in-halo adds Halo). AppKit can't
// draw an open NSMenu offscreen, so the image lays out what SuiteFileMenu gives the menu under its titles.
// `menu` also fails when Flare's own Open Recent menu is still in its File menu beside the suite's, so File
// shows one Open Recent. macOS only.
#if os(macOS)
import AppKit
import FlareModel
import Foundation
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp
@testable import SuiteShell

@MainActor @Suite struct FlareFileFlowSnapshots {
    /// A workspace with Bounce open from `path`, as the window's open leaves it.
    static func bounce(_ path: String = "/tmp/FlareFileFlowSnapshots/Bounce.flare") throws -> FlareWorkspace {
        var workspace = FlareWorkspace(services: .fake())
        workspace.finishOpen(.success(try #require(FlareFixtures.named("bounce"))), named: "Bounce.flare")
        workspace.noteRecent(path)
        return workspace
    }

    @Test func menu() async throws {
        let document = try #require(try Self.bounce().suiteDocument, "an open, saved .flare hands no document to Open In")
        let bridge = SuiteDocumentsBridge(app: .flare, services: .fake(), exists: { _ in true })
        await bridge.note(document, .opened)
        let menu = SuiteFileMenu(app: .flare, bridge: bridge, document: document)
        #expect(menu.recents.map(\.name) == ["Bounce.flare"])
        #expect(menu.openInTargets.isEmpty, "no other app reads a .flare until flare-in-halo")
        #expect(menu.openInHelp != nil, "Open In is off without saying why")
        let file = try String(contentsOf: packageRoot().appending(path: "Sources/FlareApp/FlareCommands.swift"), encoding: .utf8)
        #expect(!file.contains("Menu(\"Open Recent\")"), "Flare's own Open Recent shows beside the suite's")
        #expect(file.contains("SuiteFileCommands(app: .flare"), "File has no suite Open Recent and Open In")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(FlareFileMenuPanel(menu: menu), name: "flare-open-recent-\(scheme.name)", scheme: scheme)
        }
    }
}

/// File's Open Recent ▸ and Open In ▸ for Flare: each title with its submenu's rows or Open In's reason, on a
/// panel at the top left of the frame.
private struct FlareFileMenuPanel: View {
    let menu: SuiteFileMenu

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Text("Open Recent").font(SuiteFont.headline)
            ForEach(menu.recents, id: \.fileID) { file in
                Button(file.name) {}.buttonStyle(.borderless)
            }
            Button("Clear Menu") {}.buttonStyle(.borderless).disabled(menu.recentsEmpty)
            Divider()
            Button("Open In") {}.buttonStyle(.borderless).disabled(menu.openInTargets.isEmpty)
            ForEach(menu.openInTargets, id: \.self) { app in
                Button(app.displayName) {}.buttonStyle(.borderless)
            }
            if let help = menu.openInHelp {
                Text(help).font(SuiteFont.caption).foregroundStyle(.secondary)
            }
        }
        .padding(SuiteSpacing.l)
        .fixedSize()
        .background(SuiteColor.panel)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif
