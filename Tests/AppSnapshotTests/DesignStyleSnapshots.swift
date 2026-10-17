// DesignStyleSnapshots.swift: Design's inspector over several layers with the
// style rows (style-rows SR-a): A and B on `cards`, on the live services, whose
// X, Y and W differ ("Mixed") and whose H is 80 for both. Writes
// design-inspector-several-mixed-{light,dark}.png. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignStyleSnapshots {
    @Test func severalMixed() throws {
        var model = DesignFixtures.cards
        model.useServices(.live)
        model.selectItem("node-2")
        model.toggleSelection("node-3")
        #expect(model.selectionCountText == "2 Layers")
        #expect(model.sharedValue { $0.frame.x } == nil)
        #expect(model.sharedValue { $0.frame.y } == nil)
        #expect(model.sharedValue { $0.frame.width } == nil)
        #expect(model.sharedValue { $0.frame.height } == 80)
        for scheme in [ColorScheme.light, .dark] {
            let name = "design-inspector-several-mixed-\(scheme == .dark ? "dark" : "light")"
            try snapshot(panel(model), name: name, scheme: scheme)
        }
    }

    /// The inspector at the editor's panel width, top left on the snapshot.
    private func panel(_ model: DesignWorkspace) -> some View {
        DesignInspector(model: model, perform: { _ in })
            .frame(width: SuiteSize.editorPanelWidth)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
