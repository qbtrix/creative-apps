// SuiteSidebarToggleColumnSnapshots.swift: #53's regression shot. Four
// SidebarRows with an eye and a lock toggle in every on/off mix, so the
// narrow and wide symbols (eye / eye.slash, lock / lock.open) sit in rows
// next to each other. The eyes must form one column and the locks another;
// before #53 a row with an open lock drew its eye further left. Light and
// Dark. macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteSidebarToggleColumnSnapshots {
    @Test func toggleColumn() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                ToggleColumnSample(), name: "suiteui-sidebar-toggles-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }
}

private struct ToggleColumnSample: View {
    private static let rows: [(title: String, visible: Bool, locked: Bool)] = [
        ("Open Lock", true, false),
        ("Locked", true, true),
        ("Hidden, Open Lock", false, false),
        ("Hidden, Locked", false, true),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ForEach(Self.rows, id: \.title) { row in
                SidebarRow(
                    SidebarItem(
                        id: row.title, title: row.title, systemImage: "square",
                        toggles: [
                            SidebarToggle(id: "visible", title: "Visible", onSymbol: "eye", offSymbol: "eye.slash", isOn: row.visible),
                            SidebarToggle(id: "locked", title: "Locked", onSymbol: "lock", offSymbol: "lock.open", isOn: row.locked),
                        ]),
                    onToggle: { _ in })
            }
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal + SuiteSpacing.xxl)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
