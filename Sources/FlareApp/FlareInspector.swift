// FlareInspector.swift: Flare's inspector, a SegmentedTabs switch between
// Properties and Library. Properties (IT-4) shows refusals in the error color,
// the InspectorHeader from `model.inspectorSummary`, then SCENE with nothing
// selected, else TRANSFORM, FILL and TIMING (holding the `easing` editor);
// with no scene it says what to do. Library is FlareLibraryPanel. A tab click goes
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
        ForEach(errors, id: \.self) { message in
            Label(message, systemImage: "exclamationmark.circle")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.stateError)
                .padding(.horizontal, SuiteSpacing.m)
                .accessibilityIdentifier("flare.inspector.error")
        }
        if model.selectedScene != nil {
            let summary = model.inspectorSummary
            InspectorHeader(summary.title, facts: [
                InspectorFact("Kind", summary.kind), InspectorFact("Frame", "\(summary.frame)"),
                InspectorFact("Size", summary.size), InspectorFact("Keys", summary.keys.map { "\($0)" } ?? ""),
            ])
            .accessibilityIdentifier("flare.inspector.header")
            if summary.showsScene {
                FlareInspectorScene(size: model.sceneSizeText ?? "", rate: model.sceneRateText ?? "")
            } else {
                FlareInspectorGeometry(
                    rows: model.animatedProperties,
                    rowHelp: FlareWindow.inspectorHelp(.scrub(property: "", value: 0, dragStart: 0), in: model),
                    keyHelp: FlareWindow.inspectorHelp(.toggleKey(""), in: model), perform: perform)
                if let paint = model.paint { FlareInspectorFill(paint: paint) }
                FlareInspectorTiming(easing: easing)
            }
        } else {
            let empty = model.inspectorEmptyText
            EmptyStateView(empty.title, systemImage: "film", message: empty.message)
        }
    }

    /// The refusals to show above the header: the last layer edit's, then paint's and the timeline's.
    private var errors: [String] {
        [model.layerError?.message, model.paintError, model.timelineError].compactMap { $0 }
    }
}
