// GalleryMenus.swift: the gallery's menu pages. `menu-command` shows
// MenuCommand in a pull-down the way the apps' command menus use it: an item
// with a symbol and a key equivalent, a plain one, and one disabled with its
// reason as help.
import SwiftUI

enum GalleryMenus {
    @MainActor static let pages: GalleryPages = ["menu-command": { AnyView(GalleryMenuCommandPage()) }]
}

private struct GalleryMenuCommandPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Menu("Edit") {
                MenuCommand("Duplicate", systemImage: "plus.square.on.square", shortcut: KeyboardShortcut("d"),
                            help: "Duplicate the selection.") {}
                MenuCommand("Select All", help: "Select every layer.") {}
                MenuCommand("Paste", systemImage: "doc.on.clipboard", help: "There is nothing to paste.", isEnabled: false) {}
            }
            .fixedSize()
            .help("Edit")
            .suiteControl(id: "suite.gallery.menu-command.menu", enabled: true, reason: nil)
            Spacer()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
