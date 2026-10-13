// DesignPageMenuSnapshots.swift: Design's Page menu items in three columns,
// since the menu bar does not render here: with no file both are off, with two
// pages both are on, and with the last page Delete Page is off. Writes
// design-page-menu-light.png and design-page-menu-dark.png. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignPageMenuSnapshots {
    @Test func pageMenu() throws {
        var last = DesignWorkspace()
        last.newFile()
        var two = last
        two.addPage()
        let menus = [DesignWorkspace(), two, last].map { DesignMenu(model: $0, perform: { _ in }) }
        #expect(!menus[0].isOpen && !menus[0].canDeletePage)
        #expect(menus[1].isOpen && menus[1].canDeletePage)
        #expect(menus[2].isOpen && !menus[2].canDeletePage)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(PageMenuStates(menus: menus), name: "design-page-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct PageMenuStates: View {
    let menus: [DesignMenu]
    private let titles = ["No file", "Two pages", "Last page"]

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(menus.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    Text(titles[index]).font(SuiteFont.headline)
                    DesignPageMenu(menu: menus[index])
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
