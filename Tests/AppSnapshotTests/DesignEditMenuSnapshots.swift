// DesignEditMenuSnapshots.swift: Design's Edit menu items (Undo and Redo named
// for the edit, Delete Layer) in four columns, since the menu bar does not
// render here: a new file (nothing to undo or delete), after adding a
// rectangle ("Undo Add Rectangle", Delete Layer on), after that Undo ("Redo
// Add Rectangle"), and while a text layer is being typed into (both off, the
// model ignores them then). Writes design-edit-menu-light.png and
// design-edit-menu-dark.png. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignEditMenuSnapshots {
    @Test func editMenu() throws {
        var fresh = DesignWorkspace()
        fresh.newFile()
        var added = fresh
        added.selectTool(.rectangle)
        added.drag(from: DesignPoint(x: 100, y: 100), to: DesignPoint(x: 300, y: 240))
        added.endDrag()
        var undone = added
        undone.undo()
        var typing = added
        typing.selectTool(.text)
        typing.drag(from: DesignPoint(x: 400, y: 400), to: DesignPoint(x: 400, y: 400))
        typing.endDrag()
        let menus = [fresh, added, undone, typing].map { DesignMenu(model: $0, perform: { _ in }) }
        #expect(menus[0].undoTitle == "Undo" && !menus[0].canUndo && !menus[0].canRedo && !menus[0].canDeleteLayer)
        #expect(menus[1].undoTitle == "Undo Add Rectangle" && menus[1].canUndo && !menus[1].canRedo && menus[1].canDeleteLayer)
        #expect(menus[2].redoTitle == "Redo Add Rectangle" && !menus[2].canUndo && menus[2].canRedo && !menus[2].canDeleteLayer)
        #expect(typing.editingTextID != nil && !menus[3].canUndo && !menus[3].canRedo)
        #expect(menus[3].undoHelp == "Finish editing the text first.")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(EditMenuStates(menus: menus), name: "design-edit-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct EditMenuStates: View {
    let menus: [DesignMenu]
    private let titles = ["New file", "Rectangle added", "After Undo", "Typing text"]

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(menus.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    Text(titles[index]).font(SuiteFont.headline)
                    DesignHistoryMenu(menu: menus[index])
                    Divider()
                    DesignDeleteLayerItem(menu: menus[index])
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
