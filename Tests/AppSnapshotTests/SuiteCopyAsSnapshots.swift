// SuiteCopyAsSnapshots.swift (clipboard-interop CB-u1): the gallery's
// `menu-command` page after Copy Text, in Light and Dark. AppKit can't draw an
// open NSMenu offscreen, so each image shows the page (its Edit pull-down, the
// pasteboard line reading text and Paste as Image's help line) with the Copy
// As submenu's items and Paste as Image laid out under it the way the menu
// lists them: PNG, SVG and Gallery Layers on, Paste as Image off. Writes
// suite-gallery-copy-as-{light,dark}.png to .build/snapshots. macOS only.
import AppKit
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteCopyAsSnapshots {
    private static let size = CGSize(width: 520, height: 360)

    private static func page(_ doc: GalleryClipDocument) -> some View {
        let menu = CopyAsMenu(on: doc, ownTitle: "Gallery Layers", copy: { _ in }, pasteAsImage: {})
        return VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            GalleryMenuCommandPage(doc: doc).frame(height: 150)
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                ForEach(menu.copyItems) { $0.command }
                Divider()
                menu.pasteItem?.command
            }
            .padding(.horizontal, SuiteSpacing.m)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @Test func pasteAsImageOffAfterCopyText() throws {
        var doc = GalleryClipDocument()
        doc.copyText("hello")
        #expect(doc.pasteboardLine == "Pasteboard: text")
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for appearance in [SnapshotAppearance.light, .dark] {
            let image = try #require(SnapshotHost(appearance: appearance).render(Self.page(doc), size: Self.size))
            let png = try #require(image.representation(using: .png, properties: [:]))
            try png.write(to: folder.appending(path: "suite-gallery-copy-as-\(appearance.rawValue).png"))
        }
    }
}
