// DesignAlignSnapshots.swift: Object > Align for one layer (#417, slice 1). The
// inspector's Properties at the editor's panel width, with a rectangle
// selected inside a frame, shows the Align row, Align Left off because the
// rectangle already sits at the left edge; then the canvas after Align Center, the rectangle centered in its
// frame and still selected. Writes design-align-inspector- and
// design-align-center-{light,dark}.png. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignAlignSnapshots {
    @Test func alignRowAndAlignCenter() throws {
        var model = DesignWorkspace()
        model.newFile()
        let frame = try model.addNode(.frame, frame: DesignRect(x: 160, y: 160, width: 800, height: 500), in: "node-1")
        let rectangle = try model.addNode(.rectangle, frame: DesignRect(x: 160, y: 240, width: 200, height: 120), in: frame)
        model.selectItem(rectangle)
        #expect(model.alignHelps == [.left: "The layer is already at the left edge."])
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                AlignPanelSample(model: model), name: "design-align-inspector-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
        model.alignLayer(.center)
        #expect(model.selectedNode?.frame == DesignRect(x: 460, y: 240, width: 200, height: 120))
        #expect(model.undoActionName == "Undo Align Center")
        try shootCanvas(model, "design-align-center")
    }
}

private struct AlignPanelSample: View {
    let model: DesignWorkspace
    var body: some View {
        DesignInspector(model: model, perform: { _ in })
            .frame(width: SuiteSize.editorPanelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
