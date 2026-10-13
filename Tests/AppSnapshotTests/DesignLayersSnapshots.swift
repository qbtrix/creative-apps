// DesignLayersSnapshots.swift: Design's Pages and Layers rows (a Desktop frame holding a group of two
// shapes), expanded and with the group collapsed, as SidebarRows in a VStack, indented by depth, since
// the sidebar List does not render here.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignLayersSnapshots {
    @Test func layers() throws {
        var model = DesignWorkspace()
        model.newFile()
        model.addPage()
        model.selectPage("page-1")
        let box = DesignRect(x: 40, y: 40, width: 200, height: 120)
        let group = try model.addNode(.group, frame: box, in: "node-1")
        try model.addNode(.rectangle, frame: box, in: group)
        try model.addNode(.ellipse, frame: box, in: group)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(LayersRows(model: model), name: "design-layers-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
        // Collapsing the group hides its two shapes; its toggle turns to a right chevron, drawn at the
        // same emphasis and in the same column as the expanded Desktop's down chevron.
        try model.setExpanded(group, false)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LayersRows(model: model), name: "design-layers-collapsed-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }

    /// Collapsed is not an inactive state: the expand toggle is on in both states, so SidebarRow never
    /// dims it, and both symbols are circled chevrons of one width (#122).
    @Test func expandToggleKeepsEmphasisWhenCollapsed() {
        let expanded = SidebarItem.designExpandToggle(isExpanded: true)
        let collapsed = SidebarItem.designExpandToggle(isExpanded: false)
        #expect(expanded.isOn && collapsed.isOn)
        #expect(expanded.systemImage == "chevron.down.circle")
        #expect(collapsed.systemImage == "chevron.right.circle")
        #expect(expanded.title == "Collapse" && collapsed.title == "Expand")
    }
}

private struct LayersRows: View {
    let model: DesignWorkspace
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Pages").font(SuiteFont.headline)
            ForEach(model.pages) { SidebarRow(SidebarItem(page: $0)) }
            Text("Layers").font(SuiteFont.headline)
            ForEach(model.layerRows) { row in
                SidebarRow(SidebarItem(row: row, isExpanded: model.isExpanded(row.id))).padding(.leading, SuiteSpacing.l * CGFloat(row.depth))
            }
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal, alignment: .leading)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
    }
}
