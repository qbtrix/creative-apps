// HaloApp.swift: Halo, the motion graphics app. The window is SuiteWindow
// with the project's compositions in the sidebar, HaloViewer as content and
// the selected composition's settings and layers in the inspector. Layer > New
// (HaloCommands) reaches the window through a focused scene value. Views only
// read HaloProject and call its methods; all state lives in HaloModel
// (scripts/ci checks this).
import HaloModel
import SuiteUI
import SwiftUI

@main
struct HaloApp: App {
    var body: some Scene {
        WindowGroup { HaloWindow() }
            .commands { HaloCommands() }
    }
}

struct HaloWindow: View {
    @State private var model = HaloProject()

    var body: some View {
        SuiteWindow(
            title: model.compositions.isEmpty ? "Halo" : "Untitled Project",
            sidebarTitle: "Compositions",
            items: model.compositions.map { SidebarItem(id: $0.id, title: $0.name, systemImage: "rectangle.stack") },
            selection: model.selectedCompositionID,
            onSelect: { model.selectComposition($0) },
            actions: [ToolbarAction("New Composition", systemImage: "plus") { model.newComposition() }]
        ) {
            HaloViewer(model: model, onNew: { model.newComposition() })
        } inspector: {
            if let comp = model.selectedComposition {
                VStack(alignment: .leading, spacing: SuiteSpacing.m) {
                    SurfaceCard(title: comp.name, detail: "\(comp.width) × \(comp.height) · \(comp.framesPerSecond) fps")
                    HaloLayerList(layers: comp.layers, selection: model.selectedLayerID, onSelect: { model.selectLayer($0) })
                }
            } else {
                EmptyStateView("No Selection", systemImage: "rectangle.stack", message: "Select a composition to see its settings.")
            }
        }
        .focusedSceneValue(\.haloNewLayer, newLayer)
    }

    /// Layer > New's action, nil when no composition is selected.
    private var newLayer: (@MainActor (HaloLayerKind) -> Void)? {
        guard model.canAddLayer else { return nil }
        return { model.newLayer($0) }
    }
}

/// The main content: the composition viewer with its timecode and layer count
/// readout, or the empty state.
struct HaloViewer: View {
    let model: HaloProject
    var onNew: @MainActor () -> Void = {}

    var body: some View {
        if let comp = model.selectedComposition {
            CanvasSurface(artboard: CGSize(width: comp.width, height: comp.height), overlayAlignment: .bottom) {
                GlassPanel {
                    Text("00:00:00:00  ·  \(comp.durationSeconds.formatted()) s at \(comp.framesPerSecond) fps  ·  \(comp.layerSummary)")
                        .font(SuiteFont.monospacedDigits)
                }
            }
        } else {
            EmptyStateView(
                "No Composition", systemImage: "sparkles.rectangle.stack",
                message: "Create a composition to layer and animate footage, shapes and text.",
                action: ToolbarAction("New Composition", systemImage: "plus", perform: onNew))
        }
    }
}
