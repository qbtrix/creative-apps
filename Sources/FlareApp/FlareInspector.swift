// FlareInspector.swift: Flare's inspector, a SegmentedTabs switch between
// Properties and Library. Properties shows the selected scene's InspectorHeader
// (never a SurfaceCard, docs/design.md; its Size and Frame rate come from the
// Model, in the stage's px) and,
// while a layer is selected, the easing editor the window hands in as
// `easing` (FlareEasingInspector, until inspector-timeline retires it); with
// no scene it says what to do. Library is FlareLibraryPanel. A tab click goes
// out as `.inspector(.showTab)`; the window keeps which tab shows. It only
// reads `model`. SuiteWindow doesn't scroll its inspector, so this one
// scrolls itself (as Halo's does): unscrolled, the easing editor stood taller
// than the 1024 x 768 runner's window and pushed the window, its sidebar rows
// and the timeline off the screen (#1841). Snapshots draw it unscrolled
// (ImageRenderer can't draw a ScrollView); its indicators are `.never`, so
// no legacy scroller shows up as an unlabelled button to the app audit.
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
    @Environment(\.suiteSnapshotRendering) private var snapshot

    var body: some View {
        if snapshot {
            content
        } else {
            ScrollView(.vertical) { content }
                .scrollIndicators(.never)
        }
    }

    private var content: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var properties: some View {
        if let error = model.layerError {
            Label(error.message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(SuiteColor.secondaryText)
        }
        if let scene = model.selectedScene {
            InspectorHeader(scene.name, facts: [
                InspectorFact("Size", model.sceneSizeText ?? ""),
                InspectorFact("Frame rate", model.sceneRateText ?? ""),
            ])
            .accessibilityIdentifier("flare.inspector.header")
            if model.selectedLayerID != nil { easing }
        } else {
            let empty = model.inspectorEmptyText
            EmptyStateView(empty.title, systemImage: "film", message: empty.message)
        }
    }
}
