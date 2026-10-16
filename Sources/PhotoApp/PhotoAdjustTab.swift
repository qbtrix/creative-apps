// PhotoAdjustTab.swift: the scrolling body of a Photo window's inspector: the
// active tool's options, then (in the inspector) the selected layer's blend
// mode and opacity (PhotoLayerSettings), then the adjustment target's header
// ("Image" or the selected adjustment layer's name, over adjustHeader.info)
// and its sections, in one scroll view. Values in, intents out.
import PhotoModel
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
                if showsLayerSettings { PhotoLayerSettings(model: model, perform: perform) }
                InspectorHeader(model.adjustHeader.title, details: [model.adjustHeader.info])
                    .accessibilityIdentifier("photo.adjust.header")
                AdjustmentsPanel(model: model, perform: perform)
            }
        }
        .scrollIndicators(.never)
    }
}
