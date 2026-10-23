// FlareFileFlowSnapshots.swift (file-flow FL-2's test, FL-5's file): Flare's File menu and drop mark as the
// suite renders them for Flare. flare-open-recent-{light,dark}: Open Recent ▸ and Open In ▸ as
// SuiteFileCommands gives them for `.flare` with Bounce.flare open and in the suite's recents: the file
// listed, Clear Menu under it, and Open In off with its reason, since no other app reads a .flare yet
// (flare-in-halo adds Halo). AppKit can't draw an open NSMenu offscreen, so the image lays out what
// SuiteFileMenu gives the menu under its titles. `menu` also fails when Flare's own Open Recent menu is still
// in its File menu beside the suite's, so File shows one Open Recent.
// flare-drop-mark: the suite drop mark (SF-3) over the Flare window with Bounce open, saying what Flare's drop
// rule makes of a dropped Title.flare ("Open in Flare"), at the window's bottom as SuiteFileDropModifier puts
// it. The SVG refusal's sentence comes with FL-3, so the mark shows the open. The window bumps
// FlareWindow.bodyRuns, so the suite nests in BodyCountSuites. macOS only.
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

extension BodyCountSuites {
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

        @Test func dropMark() throws {
            let workspace = try Self.bounce()
            let actions = DropPlan.plan(
                ["/tmp/FlareFileFlowSnapshots/Title.flare"], into: SuiteApp.flare.rawValue,
                hasDocument: workspace.hasDocument, places: workspace.placesExtensions,
                readers: { SuiteDocumentsBridge.readers(in: .standard, ofExtension: $0) })
            #expect(actions == [.open(path: "/tmp/FlareFileFlowSnapshots/Title.flare")], "a dropped .flare doesn't open")
            let sentence = try #require(SuiteDropMark.sentence(for: actions, app: .flare), "no mark for Title.flare")
            #expect(sentence == "Open in Flare")
            let window = FlareWindow(model: workspace)
                .overlay(alignment: .bottom) {
                    SuiteDropMarkView(sentence: sentence, refused: SuiteDropMark.refuses(actions))
                        .padding(SuiteSpacing.l)
                        .allowsHitTesting(false)
                }
            let folder = try packageRoot().appending(path: ".build/snapshots")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let size = CGSize(width: 1440, height: 900)
            let image = try #require(SnapshotHost(appearance: .light).render(window, size: size))
            #expect(image.pixelsWide == Int(size.width * SnapshotHost.scale))
            let png = try #require(image.representation(using: .png, properties: [:]))
            try png.write(to: folder.appending(path: "flare-drop-mark.png"))
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
