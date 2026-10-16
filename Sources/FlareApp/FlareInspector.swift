// FlareInspector.swift: Flare's inspector, a SegmentedTabs switch between
// Properties and Library. Properties shows the selected scene's card and,
// while a layer is selected, the easing editor the window hands in as
// `easing` (FlareEasingInspector, until inspector-timeline retires it); with
// no scene it says what to do. Library is FlareLibraryPanel. A tab click goes
// out as `.inspector(.showTab)`; the window keeps which tab shows. It only
// reads `model`.
import FlareModel
import SuiteUI
import SwiftUI

/// The inspector's tabs; the raw value is `.inspector(.showTab)`'s payload.
enum FlareInspectorTab: String, CaseIterable, Sendable {
    case properties, library

    var title: String {
        switch self {
        case .properties: "Properties"
        case .library: "Library"
        }
    }
}

struct FlareInspector<Easing: View>: View {
    let model: FlareWorkspace
    let tab: FlareInspectorTab
    let perform: @MainActor (FlareIntent) -> Void
    let easing: Easing

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            SegmentedTabs(
                "Inspector", tabs: FlareInspectorTab.allCases.map { InspectorOption(id: $0, title: $0.title) },
                selection: tab
            ) { perform(.inspector(.showTab($0.rawValue))) }
            switch tab {
            case .properties: properties
            case .library: FlareLibraryPanel(model: model, perform: perform)
            }
        }
    }

    @ViewBuilder private var properties: some View {
        if let error = model.layerError {
            Label(error.message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(SuiteColor.secondaryText)
        }
        if let scene = model.selectedScene {
            SurfaceCard(title: scene.name, detail: "\(Int(scene.width)) × \(Int(scene.height)) pt · \(scene.fps) fps")
            if model.selectedLayerID != nil { easing }
        } else {
            EmptyStateView("No Selection", systemImage: "film", message: "Select a scene to see its properties.")
        }
    }
}
