// DesignViewMenuSnapshots.swift: Design's View menu items in three columns,
// since the menu bar does not render here: with no file the zoom items are off
// and Snap to Layers stays on (a preference, snapping SN-8), with a file open
// the zoom items are on, and with Snap to Layers stored off its checkmark is
// gone. Each column ends with View > Show History (DesignShowHistoryItem): on in
// a window with no file or a file open, Hide History while the panel shows, and
// off, saying why, with no Design window focused (the fourth column). Each
// column reads its own private UserDefaults suite. Writes
// design-view-menu-light.png and design-view-menu-dark.png. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignViewMenuSnapshots {
    @Test func viewMenu() throws {
        var open = DesignWorkspace()
        open.newFile()
        let names = (0..<4).map { "design.view-menu-snapshots.\($0).\(UUID().uuidString)" }
        let stores = try names.map { try #require(UserDefaults(suiteName: $0)) }
        defer { names.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) } }
        stores[2].set(false, forKey: DesignSnapSettings.defaultsKey)
        let menus = [DesignWorkspace(), open, open, DesignWorkspace()].map { DesignMenu(model: $0, perform: { _ in }) }
        #expect(!menus[0].isOpen && menus[1].isOpen)
        #expect(DesignModifiers.snapsToLayers(in: stores[0]) && !DesignModifiers.snapsToLayers(in: stores[2]))
        let columns = zip(menus, stores).map { DesignViewMenu(menu: $0, snapStore: $1) }
        let shown: (Bool) -> DesignHistoryShown? = { DesignHistoryShown(isShown: $0, toggle: {}) }
        let panels: [DesignHistoryShown?] = [shown(false), shown(false), shown(true), nil]
        let history = panels.map { DesignShowHistoryItem(panel: $0) }
        #expect(history.count == columns.count)
        let spec = DesignMenuState.spec("view.history")
        #expect(history.map { spec.availability(DesignMenuState(hasWindow: $0.panel != nil)).why == nil } == [true, true, true, false])
        #expect(history.map { $0.panel?.isShown } == [false, false, true, nil])
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(ViewMenuStates(menus: columns, history: history), name: "design-view-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct ViewMenuStates: View {
    let menus: [DesignViewMenu]
    let history: [DesignShowHistoryItem]
    private let titles = ["No file", "File open", "Snap off, History shown", "No window"]

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(menus.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    Text(titles[index]).font(SuiteFont.headline)
                    menus[index]
                    history[index]
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
