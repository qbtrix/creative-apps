// DesignFileMenuSnapshots.swift: Design's File menu items (New File, Open…,
// Save, Save As…) in three columns, since the menu bar does not render here:
// with no Design window focused only New File is on, with an empty window
// Open… is on too, and with a file open all four are. Also checks that New File
// opens a window when none is focused and that nothing else does. Writes
// design-file-menu-light.png and design-file-menu-dark.png. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignFileMenuSnapshots {
    @Test func fileMenu() throws {
        var open = DesignWorkspace()
        open.newFile()
        let menus = [DesignMenu(), DesignMenu(model: DesignWorkspace(), perform: { _ in }), DesignMenu(model: open, perform: { _ in })]
        #expect(!menus[0].hasWindow && !menus[0].isOpen)
        #expect(menus[1].hasWindow && !menus[1].isOpen)
        #expect(menus[2].hasWindow && menus[2].isOpen)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(FileMenuStates(menus: menus), name: "design-file-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func newFileWithNoWindowOpensOne() {
        var opened = 0
        let menu = DesignMenu(newWindow: { opened += 1 })
        for intent in [DesignIntent.open, .save, .saveAs, .undo, .addPage, .zoomIn] { menu.perform(intent) }
        #expect(opened == 0)
        menu.perform(.newFile)
        #expect(opened == 1)
    }
}

private struct FileMenuStates: View {
    let menus: [DesignMenu]
    private let titles = ["No window", "Empty window", "File open"]

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(menus.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    Text(titles[index]).font(SuiteFont.headline)
                    DesignFileMenu(menu: menus[index])
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
