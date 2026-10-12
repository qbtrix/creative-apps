// DesignLayersSnapshots.swift: Design's Pages and Layers rows (a Desktop frame holding a group of two
// shapes) as SidebarRows in a VStack, indented by depth, since the sidebar List does not render here.
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
                SidebarRow(SidebarItem(row: row)).padding(.leading, SuiteSpacing.l * CGFloat(row.depth))
            }
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal, alignment: .leading)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
    }
}
