// SuiteSidebarSnapshots.swift: SidebarRows with toggles, a count and one
// nested row, Light and Dark. The sidebar List is AppKit-backed and does not
// render in ImageRenderer, so the rows sit in a VStack with the child indented
// the way the list's disclosure group nests it. macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteSidebarSnapshots {
    @Test func sidebar() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(SidebarSample(), name: "suiteui-sidebar-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct SidebarSample: View {
    private static func toggles(visible: Bool, locked: Bool) -> [SidebarToggle] {
        [
            SidebarToggle(id: "visible", title: "Visible", onSymbol: "eye", offSymbol: "eye.slash", isOn: visible),
            SidebarToggle(id: "locked", title: "Locked", onSymbol: "lock", offSymbol: "lock.open", isOn: locked),
        ]
    }

    private let child = SidebarItem(
        id: "title", title: "Title Text", systemImage: "textformat", toggles: SidebarSample.toggles(visible: true, locked: true))

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Layers").font(SuiteFont.headline).foregroundStyle(SuiteColor.secondaryText)
            SidebarRow(
                SidebarItem(
                    id: "group", title: "Header Group", systemImage: "folder", toggles: Self.toggles(visible: true, locked: false),
                    children: [child]),
                onToggle: { _ in })
            SidebarRow(child, onToggle: { _ in })
                .padding(.leading, SuiteSpacing.l)
            SidebarRow(
                SidebarItem(id: "bg", title: "Background", systemImage: "rectangle", toggles: Self.toggles(visible: false, locked: true)),
                onToggle: { _ in })
            SidebarRow(SidebarItem(id: "all", title: "All Photos", systemImage: "photo.on.rectangle.angled", count: 12))
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal + SuiteSpacing.xxl)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
