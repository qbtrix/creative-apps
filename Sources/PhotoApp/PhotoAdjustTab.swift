// PhotoAdjustTab.swift: the scrolling body of a Photo window's inspector: the
// active tool's options, then (in the inspector) the selected layer's blend
// mode and opacity (PhotoLayerSettings) and, for a text layer, its Text
// section (PhotoTextInspector), then the adjustment target's header
// ("Image" or the selected adjustment layer's name, over adjustHeader.info)
// and its sections, then Looks (PhotoLooks, on the workspace's look store),
// in one scroll view. Values in, intents out. Everything under the tool
// options is PhotoAdjustSections, which is equal while every facet but
// `toolOptions` is, so a brush-size step re-runs the options and skips the
// adjustment sections.
import PhotoModel
import SuiteImaging
import SuiteUI
import SwiftUI

struct PhotoAdjustTab: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    /// Shows PhotoLayerSettings between Tool Options and the adjustments; the inspector sets it.
    var showsLayerSettings = false

    var body: some View {
        // No scroller: its page areas are buttons VoiceOver can't name
        // (the app audit's unnamed check); the panel still scrolls.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ToolOptionsSection(model: model, perform: perform)
                PhotoAdjustSections(model: model, perform: perform, showsLayerSettings: showsLayerSettings)
                    .equatable()
            }
        }
        .scrollIndicators(.never)
    }
}

/// The tab under the tool options: the layer's settings, the adjustment sections and Looks. None shows an option,
/// so two are equal while every facet but `toolOptions` is (`perform` is always the window's).
struct PhotoAdjustSections: View, Equatable {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    let showsLayerSettings: Bool

    var body: some View {
        if showsLayerSettings {
            PhotoLayerSettings(model: model, perform: perform)
            PhotoTextInspector(model: model, perform: perform)
        }
        InspectorHeader(model.adjustHeader.title, details: [model.adjustHeader.info])
            .accessibilityIdentifier("photo.adjust.header")
        AdjustmentsPanel(model: model, perform: perform)
        PhotoLooks(model: model, perform: perform)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.showsLayerSettings == rhs.showsLayerSettings
            && lhs.model.facets.equal(to: rhs.model.facets, except: .toolOptions)
    }
}

/// The Looks section: the built-in looks, then the ones saved in the workspace's store. Apply, Save and Delete
/// run the catalog's look commands (PhotoWindow+Filter.swift); a save or delete re-reads the store.
struct PhotoLooks: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    /// Bumped after a save or delete so the rows re-read the store.
    @State private var revision = 0

    var body: some View {
        let rows = LookGridRows(model.looks)
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader("Looks", details: ["\(rows.looks.count) looks"])
                .accessibilityIdentifier("photo.looks.header")
            LookGrid(rows: rows, target: model, onApply: { perform(.filter(.applyLook($0))) }, onSave: { name in
                perform(.filter(.saveLook(name)))
                revision += 1
            }, onDelete: { id in
                perform(.filter(.deleteLook(id)))
                revision += 1
            })
            .padding(SuiteSpacing.m)
            .id(revision)
        }
    }
}
