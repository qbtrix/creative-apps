// PhotoFileFlowSnapshots.swift (file-flow PF-2's test, PF-5's file): Photo's File menu as the suite renders
// it for Photo. photo-open-recent-{light,dark}: Open Recent ▸ and Open In ▸ as SuiteFileCommands gives them
// for `.photo` with Sunset.png open and in the suite's recents: the file listed, Clear Menu under it, and
// Open In offering Library. AppKit can't draw an open NSMenu offscreen, so the image lays out what
// SuiteFileMenu gives the menu under its titles. `menu` also fails when Photo's own Open Recent menu is
// still in its File menu beside the suite's, so File shows one Open Recent. photo-drop-mark (PF-5): the
// suite drop mark over the editor with Sunset.png open, saying a dropped Logo.png is placed in it. Nests in
// BodyCountSuites, as the drop mark renders the editor (PhotoEditor.bodyRuns). macOS only.
#if os(macOS)
import AppKit
import CoreRaster
import Foundation
import PhotoModel
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteShell

extension BodyCountSuites {
    @MainActor @Suite struct PhotoFileFlowSnapshots {
        /// A workspace with a 4 x 3 image open from `path`.
        static func sunset(_ path: String = "/tmp/PhotoFileFlowSnapshots/Sunset.png") throws -> PhotoWorkspace {
            var workspace = PhotoWorkspace(services: .fake)
            let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
            try workspace.openImage(
                try ImageIOCodec().encode(white, as: .png, quality: 1), name: "Sunset.png", codec: ImageIOCodec())
            workspace.updateFileFlow(recents: [], documentPath: path)
            return workspace
        }

        @Test func menu() async throws {
            let workspace = try Self.sunset()
            let document = try #require(workspace.suiteDocument, "an open, saved PNG hands no document to Open In")
            let bridge = SuiteDocumentsBridge(app: .photo, services: .fake(), exists: { _ in true })
            await bridge.note(document, .opened)
            let menu = SuiteFileMenu(app: .photo, bridge: bridge, document: document)
            #expect(menu.recents.map(\.name) == ["Sunset.png"])
            #expect(menu.openInTargets == [.library])
            #expect(menu.openInHelp == nil)
            let file = try String(contentsOf: packageRoot().appending(path: "Sources/PhotoApp/PhotoCommands+File.swift"), encoding: .utf8)
            #expect(!file.contains("Menu(\"Open Recent\")"), "Photo's own Open Recent shows beside the suite's")
            #expect(file.contains("SuiteFileCommands(app: .photo"), "File has no suite Open Recent and Open In")
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(PhotoFileMenuPanel(menu: menu), name: "photo-open-recent-\(scheme.name)", scheme: scheme)
            }
        }

        /// photo-drop-mark: Logo.png hovering over the window with Sunset.png open. Photo's drop rule places
        /// it, and the mark at the window's bottom names the open image, as SuiteFileDropModifier puts it.
        @Test func dropMark() throws {
            var model = PhotoWorkspace()
            let (w, h) = (640, 400)
            var bytes = [UInt8](repeating: 255, count: w * h * 4)
            for y in 0..<h {
                for x in 0..<w {
                    bytes[(y * w + x) * 4] = 250
                    bytes[(y * w + x) * 4 + 1] = UInt8(90 + 140 * y / h)
                    bytes[(y * w + x) * 4 + 2] = UInt8(60 + 120 * x / w)
                }
            }
            try model.open(rgba8: bytes, width: w, height: h, name: "Sunset.png")
            let actions = DropPlan.plan(
                ["/tmp/PhotoFileFlowSnapshots/Logo.png"], into: SuiteApp.photo.rawValue, hasDocument: model.hasDocument,
                places: model.placesExtensions,
                readers: { SuiteDocumentsBridge.readers(in: .standard, ofExtension: $0) })
            #expect(actions == [.place(path: "/tmp/PhotoFileFlowSnapshots/Logo.png")], "Photo doesn't place a dropped PNG")
            let sentence = try #require(SuiteDropMark.sentence(for: actions, app: .photo, documentName: model.documentName))
            #expect(sentence == "Place in Sunset.png")
            let view = PhotoEditor(model: model, tiles: try photoTiles(model), renderMilliseconds: 8, zoom: 1)
                .overlay(alignment: .bottom) {
                    SuiteDropMarkView(sentence: sentence, refused: false)
                        .padding(SuiteSpacing.l)
                        .allowsHitTesting(false)
                }
            try snapshot(view, name: "photo-drop-mark", scheme: .light)
        }
    }
}

/// File's Open Recent ▸ and Open In ▸ for Photo: each title with its submenu's rows, on a panel at the top
/// left of the frame.
private struct PhotoFileMenuPanel: View {
    let menu: SuiteFileMenu

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Text("Open Recent").font(SuiteFont.headline)
            ForEach(menu.recents, id: \.fileID) { file in
                Button(file.name) {}.buttonStyle(.borderless)
            }
            Button("Clear Menu") {}.buttonStyle(.borderless).disabled(menu.recentsEmpty)
            Divider()
            Text("Open In").font(SuiteFont.headline)
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
