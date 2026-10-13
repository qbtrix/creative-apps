// DesignInspectorSnapshots.swift: Design's panel on the Properties tab at the
// editor's panel width: a page with no layer selected, a rectangle selected
// (Layer, Frame and Fill), and a locked rectangle (Frame and Fill disabled,
// with the line saying why). Writes design-inspector-page-, -node- and
// -locked-{light,dark}.png. macOS only.
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
