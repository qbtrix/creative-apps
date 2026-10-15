// PhotoEditMenuSnapshots.swift: Photo's Edit menu items with no image open
// (all disabled but the system's) beside an image with the whole canvas
// selected (Select All, Delete Selection and Fill Selection enabled), each
// with its SF Symbol, in Light and Dark. The menu bar doesn't render here,
// so the items are drawn in columns, as PhotoLayerMenuSnapshots does. Writes
// photo-edit-menu-light.png and photo-edit-menu-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoEditMenuSnapshots {
    @Test func editMenuStates() throws {
        var selected = PhotoWorkspace()
        try selected.newCanvas(width: 1920, height: 1080)
        selected.selectAll()
        let menus = [PhotoWorkspace(), selected].map { PhotoMenu(model: $0, perform: { _ in }) }
        #expect(!menus[0].canEditSelection && menus[1].canEditSelection && menus[1].canSelectAll)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                EditMenuStates(menus: menus), name: "photo-edit-menu-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }
}

private struct EditMenuStates: View {
    let menus: [PhotoMenu]
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(menus.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    PhotoUndoMenu(menu: menus[index])
                    Divider()
                    PhotoPasteboardMenu(menu: menus[index])
                    PhotoSelectionEditMenu(menu: menus[index])
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
