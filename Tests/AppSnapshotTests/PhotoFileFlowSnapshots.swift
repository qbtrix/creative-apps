// PhotoFileFlowSnapshots.swift (file-flow PF-2's test, PF-5's file): Photo's file flow, checked against goldens
// in Golden/photo/. `menu`: Open Recent ▸ and Open In ▸ as SuiteFileCommands gives them for `.photo` with
// Sunset.png open and in the suite's recents (the file listed, Open In offering Library), and no second Open
// Recent of Photo's own in its File menu. AppKit can't draw an open NSMenu offscreen and a hand-drawn panel only
// golds a look-alike, so the open menu's picture is PhotoJourneyTests' screenshot, not a golden here.
// photo-opened-detail (light, dark): an opened photo on the canvas, with the palette and status line.
// photo-drop-mark: the suite drop mark over that column with Sunset.png open, saying a dropped Logo.png is
// placed in it. Both draw PhotoEditorDetail through SnapshotHost at 2x, since the split view (SuiteWindow) draws
// its sidebar and inspector blank offscreen. Nests in BodyCountSuites, as these render editor views. macOS only.
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
        }

        static let detailSize = CGSize(width: 960, height: 800)

        /// Sunset.png, 640 x 400 of warm gradient, opened as the window opens a file.
        static func opened() throws -> PhotoWorkspace {
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
            return model
        }

        /// photo-opened-detail: the opened photo on the canvas, as the window's middle column draws it.
        @Test func openedDetail() throws {
            let model = try Self.opened()
            for appearance in [SnapshotAppearance.light, .dark] {
                assertGolden(PhotoEditorDetail(model: model, tiles: try photoTiles(model), renderMilliseconds: 8),
                             size: Self.detailSize, name: "photo-opened-detail", area: "photo", appearance: appearance)
            }
        }

        /// photo-drop-mark: Logo.png hovering over the window with Sunset.png open. Photo's drop rule places
        /// it, and the mark at the window's bottom names the open image, as SuiteFileDropModifier puts it.
        @Test func dropMark() throws {
            let model = try Self.opened()
            let actions = DropPlan.plan(
                ["/tmp/PhotoFileFlowSnapshots/Logo.png"], into: SuiteApp.photo.rawValue, hasDocument: model.hasDocument,
                places: model.placesExtensions,
                readers: { SuiteDocumentsBridge.readers(in: .standard, ofExtension: $0) })
            #expect(actions == [.place(path: "/tmp/PhotoFileFlowSnapshots/Logo.png")], "Photo doesn't place a dropped PNG")
            let sentence = try #require(SuiteDropMark.sentence(for: actions, app: .photo, documentName: model.documentName))
            #expect(sentence == "Place in Sunset.png")
            let view = PhotoEditorDetail(model: model, tiles: try photoTiles(model), renderMilliseconds: 8)
                .overlay(alignment: .bottom) {
                    SuiteDropMarkView(sentence: sentence, refused: false)
                        .padding(SuiteSpacing.l)
                        .allowsHitTesting(false)
                }
            assertGolden(view, size: Self.detailSize, name: "photo-drop-mark", area: "photo", appearance: .light)
        }
    }
}

#endif
