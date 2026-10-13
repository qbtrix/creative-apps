// SuiteSidebarNestingSnapshots.swift: a three-level item tree capped at two
// levels, Light and Dark. The top row sits flush and its secondLevelRows sit
// one indent in, the way SidebarNode's disclosure group nests them, so "Level 3"
// lines up with "Level 2" instead of a third indent. macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteSidebarNestingSnapshots {
    @Test func capped() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(NestingSample(), name: "suiteui-sidebar-nesting-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct NestingSample: View {
    private let top: SidebarItem = {
        let leaf = SidebarItem(id: "c", title: "Level 3", systemImage: "square")
        let mid = SidebarItem(id: "b", title: "Level 2", systemImage: "folder", children: [leaf])
        return SidebarItem(id: "a", title: "Level 1", systemImage: "folder", children: [mid])
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Layers").font(SuiteFont.headline).foregroundStyle(SuiteColor.secondaryText)
            SidebarRow(top)
            ForEach(top.secondLevelRows) { SidebarRow($0).padding(.leading, SuiteSpacing.l) }
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal + SuiteSpacing.xxl)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
