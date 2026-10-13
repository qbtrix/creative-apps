// DesignInspectorSnapshots.swift: Design's panel on the Properties tab at the
// editor's panel width: a page with no layer selected, a rectangle selected
// (Layer, Frame and Fill), a locked rectangle (Frame and Fill disabled,
// with the line saying why), and a rectangle inside a locked group (disabled
// the same way). Writes design-inspector-page-, -node-, -locked- and
// -locked-group-{light,dark}.png. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignInspectorSnapshots {
    private func shoot(_ state: String, _ model: DesignWorkspace) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PanelSample(model: model), name: "design-inspector-\(state)-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }

    @Test func pageAndLayer() throws {
        var model = DesignWorkspace()
        model.newFile()
        try shoot("page", model)
        let box = DesignRect(x: 40.4, y: 56, width: 160.4, height: 119.6)
        let rectangle = try model.addNode(.rectangle, frame: box, in: "node-1")
        try model.setFill(rectangle, DesignColor(24, 119, 242))
        try shoot("node", model)
        try model.setNodeLocked(rectangle, true)
        try shoot("locked", model)
    }

    @Test func layerInsideALockedGroup() throws {
        var model = DesignWorkspace()
        model.newFile()
        let group = try model.addNode(.group, frame: DesignRect(x: 40, y: 40, width: 240, height: 180), in: "node-1")
        let rectangle = try model.addNode(.rectangle, frame: DesignRect(x: 60, y: 64, width: 120, height: 90), in: group)
        try model.setNodeLocked(group, true)
        model.selectItem(rectangle)
        try shoot("locked-group", model)
    }
}

private struct PanelSample: View {
    let model: DesignWorkspace
    var body: some View {
        DesignPanel(model: model, tab: .properties)
            .frame(width: SuiteSize.editorPanelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
