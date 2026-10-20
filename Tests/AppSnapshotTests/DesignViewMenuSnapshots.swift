// DesignViewMenuSnapshots.swift: Design's View menu items in three columns,
// since the menu bar does not render here: with no file the zoom items are off
// and Snap to Layers stays on (a preference, snapping SN-8), with a file open
// the zoom items are on, and with Snap to Layers stored off its checkmark is
// gone. Each column reads its own private UserDefaults suite. Writes
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
        let names = (0..<3).map { "design.view-menu-snapshots.\($0).\(UUID().uuidString)" }
        let stores = try names.map { try #require(UserDefaults(suiteName: $0)) }
        defer { names.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) } }
        stores[2].set(false, forKey: DesignSnapSettings.defaultsKey)
        let menus = [DesignWorkspace(), open, open].map { DesignMenu(model: $0, perform: { _ in }) }
        #expect(!menus[0].isOpen && menus[1].isOpen)
        #expect(DesignModifiers.snapsToLayers(in: stores[0]) && !DesignModifiers.snapsToLayers(in: stores[2]))
        let columns = zip(menus, stores).map { DesignViewMenu(menu: $0, snapStore: $1) }
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(ViewMenuStates(menus: columns), name: "design-view-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct ViewMenuStates: View {
    let menus: [DesignViewMenu]
    private let titles = ["No file", "File open", "Snap off"]

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(menus.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    Text(titles[index]).font(SuiteFont.headline)
                    menus[index]
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
