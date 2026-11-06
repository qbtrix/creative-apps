// SuiteCopyAsMenuSnapshots.swift (clipboard-interop CB-u1): suite-gallery-copy-as-light and -dark. The
// gallery's `menu-command` page with text on its fake pasteboard, so Paste as Image is off and the page's help
// line gives the coder's sentence. AppKit can't draw an open NSMenu offscreen, so beside the page the Copy As
// submenu's items and Paste as Image are laid out as the menu shows them (SuiteRenderingMenuSnapshots does the
// same). macOS only.
#if canImport(AppKit)
import Foundation
import SuiteKernel
import SuiteModel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteCopyAsMenuSnapshots {
    @Test func pasteOffInBothSchemes() throws {
        let doc = GalleryClipDocument(offered: [TypedData(type: .plainText, data: Data("hello".utf8))])
        let menu = CopyAsMenu(on: doc, ownTitle: "Gallery Layers", copy: { _ in }, pasteAsImage: {})
        let paste = try #require(menu.pasteItem)
        #expect(menu.copyItems.map(\.command.title) == ["PNG", "SVG", "Gallery Layers"])
        #expect(!paste.command.isEnabled && paste.command.help.hasPrefix("Paste as Image: "), "\(paste.command.help)")
        let page = HStack(alignment: .top, spacing: SuiteSpacing.xl) {
            GalleryMenuCommandPage(doc: doc).frame(width: 480)
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                Text("Copy As").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
                ForEach(menu.copyItems) { $0.command }
                Divider().frame(width: 200)
                paste.command
            }
            .padding(SuiteSpacing.m)
            Spacer()
        }
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(page, name: "suite-gallery-copy-as-\(scheme.name)", scheme: scheme)
        }
    }
}
#endif
