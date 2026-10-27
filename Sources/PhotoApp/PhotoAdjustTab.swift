// PhotoAdjustTab.swift: the scrolling body of a Photo window's inspector: the
// active tool's options, then (in the inspector) the selected layer's blend
// mode and opacity (PhotoLayerSettings) and, for a text layer, its Text
// section (PhotoTextInspector), then the adjustment target's header
// ("Image" or the selected adjustment layer's name, over adjustHeader.info)
// and its sections, then Looks (PhotoLooks), in one scroll view. Values in,
// intents out.
import PhotoModel
import SuiteImaging
import SuiteUI
import SwiftUI

struct PhotoAdjustTab: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    /// Shows PhotoLayerSettings between Tool Options and the adjustments; the inspector sets it.
    var showsLayerSettings = false
    /// Where Looks reads and saves: a fake store until AJ-8 gives the workspace its own.
    var looks = PendingAdjustTarget()

    var body: some View {
        // No scroller: its page areas are buttons VoiceOver can't name
        // (the app audit's unnamed check); the panel still scrolls.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ToolOptionsSection(model: model, perform: perform)
                if showsLayerSettings {
                    PhotoLayerSettings(model: model, perform: perform)
                    PhotoTextInspector(model: model, perform: perform)
                }
                InspectorHeader(model.adjustHeader.title, details: [model.adjustHeader.info])
                    .accessibilityIdentifier("photo.adjust.header")
                AdjustmentsPanel(model: model, perform: perform)
                PhotoLooks(target: looks)
            }
        }
        .scrollIndicators(.never)
    }
}

/// The Looks section: the built-in looks, then the ones saved in the target's store. Save and Delete write that
/// store and re-read it; applying waits on the target (AJ-8), so the grid's tooltip says why.
struct PhotoLooks: View {
    let target: PendingAdjustTarget
    /// Bumped after a save or delete so the rows re-read the store.
    @State private var revision = 0

    var body: some View {
        let rows = LookGridRows(target.looks)
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader("Looks", details: ["\(rows.looks.count) looks"])
                .accessibilityIdentifier("photo.looks.header")
            LookGrid(rows: rows, target: target, onSave: { name in
                if let r = try? LookGridRows.record(target.currentLook, name: name) { try? target.looks.save(r) }
                revision += 1
            }, onDelete: { id in
                try? target.looks.delete(id: id, kind: LookPreset.recordKind)
                revision += 1
            })
            .padding(SuiteSpacing.m)
            .id(revision)
        }
    }
}
