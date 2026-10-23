// DesignFileMenuSnapshots.swift: Design's File menu items (New File, Open…,
// Close, Save, Save As…) in three columns, since the menu bar does not render here:
// with no Design window focused only New File and Close are on, with an empty window
// Open… is on too, and with a file open all five are. Also checks that New File
// opens a window when none is focused and that nothing else does. Writes
// design-file-menu-light.png and design-file-menu-dark.png. A second shot shows an
// edited window's File menu, Close ⌘W on, beside the question ⌘W asks there
// (the Model's closePrompt, naming "Untitled"), and checks that Edit > Undo goes to a
// focused text field and otherwise to the document (the Model's undoTarget). Writes
// design-file-menu-close-light.png and design-file-menu-close-dark.png. macOS only.
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

    @Test func closeOnAnEditedWindow() throws {
        var edited = DesignWorkspace()
        edited.newFile()
        #expect(edited.closePrompt == nil)
        edited.selectTool(.rectangle)
        edited.drag(from: DesignPoint(x: 100, y: 100), to: DesignPoint(x: 300, y: 240))
        edited.endDrag()
        let prompt = try #require(edited.closePrompt)
        #expect(prompt == "Do you want to save the changes made to the document “Untitled”?")
        let menu = DesignMenu(model: edited, perform: { _ in })
        #expect(menu.undoTarget(true) == .field && menu.undoTarget(false) == .document)
        #expect(DesignMenu().undoTarget(true) == .field)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                CloseStates(menu: menu, prompt: prompt),
                name: "design-file-menu-close-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
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

/// An edited window's File menu (Close ⌘W on) beside the close prompt's message and choices.
private struct CloseStates: View {
    let menu: DesignMenu
    let prompt: String

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                Text("Edited window").font(SuiteFont.headline)
                DesignFileMenu(menu: menu)
            }
            .labelStyle(.titleAndIcon)
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                Text("⌘W asks").font(SuiteFont.headline)
                Text(prompt)
                HStack(spacing: SuiteSpacing.s) {
                    Button("Don't Save") {}
                    Button("Cancel") {}
                    Button("Save") {}.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
