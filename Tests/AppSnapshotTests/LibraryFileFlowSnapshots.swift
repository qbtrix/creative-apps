// LibraryFileFlowSnapshots.swift (file-flow LF-5): Library's File menu and drop mark as the suite renders
// them for Library. library-open-recent-{light,dark}: Open Recent ▸ and Open In ▸ as SuiteFileCommands
// gives them for `.library` with no document handed in: Library is one catalog with no recent files of its
// own, so "No Recent Files" is disabled, and Open In is off with "Open a document first.". AppKit can't
// draw an open NSMenu offscreen, so the image lays out what SuiteFileMenu gives the menu under its titles.
// library-drop-mark (light) and library-drop-mark-dark: the suite drop mark (SF-3) over the Library window
// on the samples fixture, saying what Library's drop rule makes of three dropped JPEGs, at the window's
// bottom as SuiteFileDropModifier puts it. The window bumps LibraryWindow.bodyRuns, so the suite nests in BodyCountSuites. macOS only.
#if os(macOS)
import AppKit
import Foundation
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel
@testable import SuiteShell

extension BodyCountSuites {
    @MainActor @Suite struct LibraryFileFlowSnapshots {
        @Test func openRecent() throws {
            let menu = SuiteFileMenu(app: .library, bridge: SuiteDocumentsBridge(app: .library, services: .fake()))
            #expect(menu.recentsEmpty, "Library has no recent files of its own")
            #expect(menu.openInTargets.isEmpty)
            #expect(menu.openInHelp == SuiteFileCommands.openInHelp)
            for scheme in [ColorScheme.light, .dark] {
                let suffix = scheme == .dark ? "dark" : "light"
                try snapshot(LibraryFileMenuPanel(menu: menu), name: "library-open-recent-\(suffix)", scheme: scheme)
            }
        }

        @Test func dropMark() throws {
            let catalog = LibraryCatalog(services: .fake())
            let photos = ["beach.jpg", "dunes.jpg", "pier.jpg"].map { "/tmp/LibraryFileFlowSnapshots/\($0)" }
            let actions = DropPlan.plan(
                photos, into: SuiteApp.library.rawValue, hasDocument: catalog.hasDocument,
                places: catalog.placesExtensions,
                readers: { SuiteDocumentsBridge.readers(in: .standard, ofExtension: $0) })
            #expect(actions.count == 3)
            #expect(!SuiteDropMark.refuses(actions), "Library refuses JPEGs: \(actions)")
            let sentence = try #require(SuiteDropMark.sentence(for: actions, app: .library, documentName: LibraryWindow.dropTarget), "no mark for JPEGs")
            #expect(sentence == "Place in Library", "the mark doesn't name Library: \(sentence)")
            let window = LibraryWindow(arguments: ["Library", "-LibraryFixture", "samples"])
                .overlay(alignment: .bottom) {
                    SuiteDropMarkView(sentence: sentence, refused: false)
                        .padding(SuiteSpacing.l)
                        .allowsHitTesting(false)
                }
            let folder = try packageRoot().appending(path: ".build/snapshots")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let size = CGSize(width: 1440, height: 900)
            for (appearance, name) in [(SnapshotAppearance.light, "library-drop-mark"), (.dark, "library-drop-mark-dark")] {
                let image = try #require(SnapshotHost(appearance: appearance).render(window, size: size))
                #expect(image.pixelsWide == Int(size.width * SnapshotHost.scale))
                let png = try #require(image.representation(using: .png, properties: [:]))
                try png.write(to: folder.appending(path: "\(name).png"))
            }
        }
    }
}

/// File's Open Recent ▸ and Open In ▸ for Library, each title with what its submenu or help shows, on a
/// panel at the top left of the frame.
private struct LibraryFileMenuPanel: View {
    let menu: SuiteFileMenu

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Text("Open Recent").font(SuiteFont.headline)
            Button(SuiteFileMenu.noRecentFiles) {}.buttonStyle(.borderless).disabled(menu.recentsEmpty)
            Divider()
            Button("Open In") {}.buttonStyle(.borderless).disabled(menu.openInTargets.isEmpty)
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
