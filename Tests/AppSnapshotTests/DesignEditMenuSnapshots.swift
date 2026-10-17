// DesignEditMenuSnapshots.swift: Design's Edit menu items (Undo and Redo named
// for the edit, Delete Layer) in four columns, since the menu bar does not
// render here: a new file (nothing to undo or delete), after adding a
// rectangle ("Undo Add Rectangle", Delete Layer on), after that Undo ("Redo
// Add Rectangle"), and while a text layer is being typed into (Undo, Redo and
// Delete Layer off, the model ignores them then). Writes design-edit-menu-light.png and
// design-edit-menu-dark.png. A second shot shows Duplicate after the system's Cut, Copy,
// Paste and Select All (drawn here as plain stand-ins, since the system adds them): off
// with nothing selected, its tooltip "Select a layer first.", and on with a layer selected
// on the fixture fakes. Writes design-edit-menu-duplicate-light.png and -dark.png. macOS only.
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
        #expect(typing.editingTextID != nil && !menus[3].canUndo && !menus[3].canRedo && !menus[3].canDeleteLayer)
        #expect(menus[3].undoHelp == "Finish editing the text first.")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(EditMenuStates(menus: menus), name: "design-edit-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

extension DesignEditMenuSnapshots {
    @Test func duplicate() throws {
        var none = DesignWorkspace()
        none.newFile()
        var one = DesignWorkspace()
        one.useServices(.fake)
        let opened = one.openFixture("cards")
        #expect(opened)
        one.selectItem(one.selectedPage?.nodes.last?.id ?? "")
        let menus = [none, one].map { DesignMenu(model: $0, perform: { _ in }) }
        #expect(menus[0].help(.duplicate) == "Select a layer first.")
        #expect(!one.selectedNodeIDs.isEmpty && menus[1].help(.duplicate) == nil)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(DuplicateStates(menus: menus), name: "design-edit-menu-duplicate-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

/// Duplicate under stand-ins for the system's pasteboard group, which the menu bar keeps above it.
private struct DuplicateStates: View {
    let menus: [DesignMenu]
    private let titles = ["Nothing selected", "A layer selected"]

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(menus.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    Text(titles[index]).font(SuiteFont.headline)
                    ForEach(["Cut", "Copy", "Paste", "Select All"], id: \.self) { Button($0) {}.disabled(true) }
                    Divider()
                    DesignEditItems(menu: menus[index])
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
