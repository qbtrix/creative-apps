// SuiteSidebarNestingSnapshots.swift: a three-level item tree in the real
// sidebar List (SuiteSidebarList, so every row is a SidebarNode), Light and
// Dark, in suiteui-sidebar-nesting-{light,dark}.png. Level 1 is opened through
// LL-9's expansion seam (`sidebarExpansion`, the window's expanded/onExpand),
// so its disclosure chevron points down, Level 2 sits one system indent in,
// and Level 3 lines up with Level 2: SidebarNode nests `secondLevelRows`, the
// two-level cap. With the cap reverted (`children` in SidebarSection.swift),
// Level 2 gets a chevron of its own and Level 3 a third indent, so the PNG
// changes (LL-10, #249). macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteSidebarNestingSnapshots {
    @Test func capped() throws {
        // The seam the snapshot opens Level 1 through: the app's set, not the group's own state.
        let open = SidebarNode.expansion(for: "a", in: NestingSample.expansion, local: .constant(false))
        #expect(open.wrappedValue)
        // The cap: Level 2 and Level 3 both draw at the second level, neither with a disclosure.
        #expect(NestingSample.top.secondLevelRows.map(\.id) == ["b", "c"])
        #expect(NestingSample.top.secondLevelRows.allSatisfy { $0.children.isEmpty })
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(NestingSample(), name: "suiteui-sidebar-nesting-\(scheme.name)", scheme: scheme)
        }
    }
}

private struct NestingSample: View {
    static let top: SidebarItem = {
        let leaf = SidebarItem(id: "c", title: "Level 3", systemImage: "square")
        let mid = SidebarItem(id: "b", title: "Level 2", systemImage: "folder", children: [leaf])
        return SidebarItem(id: "a", title: "Level 1", systemImage: "folder", children: [mid])
    }()

    /// Level 1 and Level 2 open: with the cap Level 2 has no group, so only
    /// Level 1's chevron shows; without it Level 2 would open a third level.
    static let expansion = SidebarExpansion(expanded: ["a", "b"], onExpand: { _, _ in })

    var body: some View {
        SuiteSidebarList(
            sections: [SidebarSection(id: "layers", title: "Layers", items: [Self.top])],
            selection: nil, onSelect: { _ in })
            .environment(\.sidebarExpansion, Self.expansion)
            .frame(width: SuiteSize.sidebarWidth.ideal, height: SuiteSize.windowMinimum.height / 2)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
