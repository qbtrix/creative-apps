// LauncherCommands+Home.swift: the home feature's launcher menus (blueprint
// suite.md 6.2, HM-2c), rendered from HomeMenu over the focused window's
// HomeModel. File: New ▸ (replacing the system's New), Open… ⌘O and Open
// Recent ▸; Edit: Undo Remove from Recents after the system's Undo and Redo,
// and Delete, titled for the page, after the clipboard group the assets stub
// owns; View: Show Sidebar, Show Inspector ⌥⌘I and the thumbnail sizes,
// before the system's Enter Full Screen. With no window, New and Open… open
// it. No SidebarCommands, so Show Sidebar appears once.
import SuiteModel
import SwiftUI

struct LauncherCommandsHome: Commands {
    @FocusedValue(\.homeModel) private var model
    @Environment(\.openWindow) private var openWindow

    private var menu: HomeMenu {
        HomeMenu.make(
            recents: RecentsList(items: model?.state.cards.map(\.item) ?? []), selection: model?.selection,
            thumbnailStep: model?.thumbnailStep ?? 1, page: .home, hasWindow: model != nil,
            canUndoRemove: model?.canUndoRemove ?? false, tiles: model?.state.tiles ?? [],
            pending: LauncherServices.shared.pending)
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Menu("New") {
                ForEach(menu.new, id: \.app) { entry in
                    HomeMenuItem(item: entry.item) {
                        guard let model, let preset = entry.preset else { return openWindow(id: "home") }
                        Task { await model.newDocument(preset, now: Date()) }
                    }
                }
            }
            HomeMenuItem(item: menu.open) { openWindow(id: "home") }.keyboardShortcut("o")
            Menu("Open Recent") {
                ForEach(menu.recents, id: \.fileID) { entry in
                    HomeMenuItem(item: entry.item) {
                        guard let model else { return }
                        model.select(entry.fileID)
                        Task { await model.openSelection(now: Date()) }
                    }
                }
                Divider()
                HomeMenuItem(item: menu.clearMenu) {}
            }
        }
        CommandGroup(after: .undoRedo) {
            HomeMenuItem(item: menu.undo) { if let model { Task { await model.undoRemove(now: Date()) } } }
        }
        CommandGroup(after: .pasteboard) {
            HomeMenuItem(item: menu.delete) { if let model { Task { await model.removeSelection(now: Date()) } } }
        }
        CommandGroup(before: .sidebar) {
            HomeMenuItem(item: menu.showSidebar) {}
            HomeMenuItem(item: menu.showInspector) {}.keyboardShortcut("i", modifiers: [.option, .command])
            Divider()
            HomeMenuItem(item: menu.larger) { model?.larger() }.keyboardShortcut("+")
            HomeMenuItem(item: menu.smaller) { model?.smaller() }.keyboardShortcut("-")
        }
    }
}

/// One HomeMenu item: disabled with its reason as help when it can't act.
private struct HomeMenuItem: View {
    let item: HomeMenu.Item
    let action: @MainActor () -> Void

    var body: some View {
        Button(item.title, action: action).disabled(!item.isEnabled).help(item.reason ?? "")
    }
}
