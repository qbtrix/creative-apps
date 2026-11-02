// HaloFileFlowSnapshots.swift (file-flow HF-2's test, HF-5's file): Halo's File menu and drop mark as the
// suite renders them for Halo. halo-open-recent-{light,dark}: Open Recent ▸ and Open In ▸ as
// SuiteFileCommands gives them for `.halo` with Spot.halo saved and in the suite's recents: the file listed,
// Clear Menu under it, and Open In off with its reason, since no other app reads a .halo yet. AppKit can't
// draw an open NSMenu offscreen, so the image lays out what SuiteFileMenu gives the menu under its titles.
// `menu` also fails when Halo's own Open Recent menu is still in its File menu beside the suite's, so File
// shows one Open Recent. halo-drop-mark-{light,dark}: the suite drop mark (SF-3) over the viewer with Spot open,
// saying what Halo's drop rule makes of a dropped Sunset.png ("Open in Photo": Halo places no images until
// S20, so Photo, which reads a PNG, gets it), at the viewer's bottom as SuiteFileDropModifier puts it.
// macOS only.
#if os(macOS)
import Foundation
import HaloModel
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp
@testable import SuiteShell

@MainActor @Suite struct HaloFileFlowSnapshots {
    /// The two-comps fixture saved as Spot.halo.
    static func spot() throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("two-comps")))
        project.didSave(name: "Spot.halo", path: "/tmp/HaloFileFlowSnapshots/Spot.halo")
        return project
    }

    @Test func menu() async throws {
        let document = try #require(try Self.spot().suiteDocument, "a saved .halo hands no document to Open In")
        let bridge = SuiteDocumentsBridge(app: .halo, services: .fake(), exists: { _ in true })
        await bridge.note(document, .opened)
        let menu = SuiteFileMenu(app: .halo, bridge: bridge, document: document)
        #expect(menu.recents.map(\.name) == ["Spot.halo"])
        #expect(menu.openInHelp != nil || !menu.openInTargets.isEmpty, "Open In is off without saying why")
        let file = try String(contentsOf: packageRoot().appending(path: "Sources/HaloApp/HaloFileMenu.swift"), encoding: .utf8)
        #expect(!file.contains("Menu(\"Open Recent\")"), "Halo's own Open Recent shows beside the suite's")
        #expect(file.contains("SuiteFileCommands(app: .halo"), "File has no suite Open Recent and Open In")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(HaloFileMenuPanel(menu: menu), name: "halo-open-recent-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func dropMark() throws {
        let project = try Self.spot()
        let actions = DropPlan.plan(
            ["/tmp/HaloFileFlowSnapshots/Sunset.png"], into: SuiteApp.halo.rawValue,
            hasDocument: project.hasDocument, places: project.placesExtensions,
            readers: { SuiteDocumentsBridge.readers(in: .standard, ofExtension: $0) })
        #expect(actions == [.handOff(path: "/tmp/HaloFileFlowSnapshots/Sunset.png", app: "photo")])
        let sentence = try #require(SuiteDropMark.sentence(for: actions, app: .halo), "no mark for Sunset.png")
        #expect(sentence == "Open in Photo")
        // The viewer, where HaloViewer.body attaches .suiteFileDrop: the mark sits at its bottom, over the
        // timeline, as a real drag shows it. HaloWindow in an offscreen host draws a strip of chrome and a
        // blank pane, so the mark landed nowhere the window draws it.
        let view = HaloViewer(model: project)
            .overlay(alignment: .bottom) {
                SuiteDropMarkView(sentence: sentence, refused: SuiteDropMark.refuses(actions))
                    .padding(SuiteSpacing.l)
                    .allowsHitTesting(false)
            }
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(view, name: "halo-drop-mark-\(scheme.name)", scheme: scheme)
        }
    }
}

/// File's Open Recent ▸ and Open In ▸ for Halo: each title with its submenu's rows or Open In's reason, on a
/// panel at the top left of the frame.
private struct HaloFileMenuPanel: View {
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
