// LauncherCommands+Home.swift: the home feature's launcher menus (blueprint
// suite.md 6.2, HM-2c), rendered from HomeMenu over the focused window's
// HomeModel. File: New ▸ (replacing the system's New), Open… ⌘O and Open
// Recent ▸ ending in Clear Menu, which empties the recents; Edit: Undo Remove
// from Recents after the system's Undo and Redo, and Remove from Recents after
// the clipboard group, on the Home page only (HomeMenu gives no Delete on the
// assets page); View: the thumbnail sizes, before the sidebar group. Show
// Sidebar and Show Inspector ⌥⌘I are the system's SidebarCommands and
// InspectorCommands (AfterGlowApp.swift), which toggle SuiteWindow's columns.
// Open… asks for files and the model routes each; with no window, New and
// Open… open it.
import SuiteModel
import SuiteUI
import SwiftUI

struct LauncherCommandsHome: Commands {
    @FocusedValue(\.homeModel) private var model
    @FocusedValue(\.homePage) private var page
    @Environment(\.openWindow) private var openWindow

    private var menu: HomeMenu {
        HomeMenu.make(
            recents: RecentsList(items: model?.state.cards.map(\.item) ?? []), selection: model?.selection,
            thumbnailStep: model?.thumbnailStep ?? 1, page: page ?? .home, hasWindow: model != nil,
            canUndoRemove: model?.canUndoRemove ?? false, tiles: model?.state.tiles ?? [],
            pending: LauncherServices.shared.pending)
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Menu("New") {
                ForEach(menu.new, id: \.app) { entry in
                    MenuCommand(item: entry.item) {
                        guard let model, let preset = entry.preset else { return openWindow(id: "home") }
                        Task { await model.newDocument(preset, now: Date()) }
                    }
                }
            }
            MenuCommand(item: menu.open) {
                guard let model else { return openWindow(id: "home") }
                let paths = HomeContent.chooseFiles()
                if !paths.isEmpty { Task { await model.open(paths: paths, now: Date()) } }
            }.keyboardShortcut("o")
            Menu("Open Recent") {
                ForEach(menu.recents, id: \.fileID) { entry in
                    MenuCommand(item: entry.item) {
                        guard let model else { return }
                        model.select(entry.fileID)
                        Task { await model.openSelection(now: Date()) }
                    }
                }
                Divider()
                MenuCommand(item: menu.clearMenu) { if let model { Task { await model.clearRecents(now: Date()) } } }
            }
        }
        CommandGroup(after: .undoRedo) {
            MenuCommand(item: menu.undo) { if let model { Task { await model.undoRemove(now: Date()) } } }
        }
        CommandGroup(after: .pasteboard) {
            if let delete = menu.delete {
                MenuCommand(item: delete) { if let model { Task { await model.removeSelection(now: Date()) } } }
            }
        }
        CommandGroup(before: .sidebar) {
            MenuCommand(item: menu.larger) { model?.larger() }.keyboardShortcut("+")
            MenuCommand(item: menu.smaller) { model?.smaller() }.keyboardShortcut("-")
            Divider()
        }
    }
}

extension MenuCommand {
    /// One HomeMenu item: disabled with its reason as help when it can't act.
    init(item: HomeMenu.Item, action: @escaping @MainActor () -> Void) {
        self.init(item.title, help: item.reason ?? "", isEnabled: item.isEnabled, perform: action)
    }
}
