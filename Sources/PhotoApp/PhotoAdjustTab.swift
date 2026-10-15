// PhotoAdjustTab.swift: the Adjust tab of a Photo window's right panel: the
// active tool's options, then the adjustment sections, in one scroll view.
// Values in, intents out.
import PhotoModel
import SwiftUI

struct PhotoAdjustTab: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        // No scroller: its page areas are buttons VoiceOver can't name
        // (the app audit's unnamed check); the panel still scrolls.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ToolOptionsSection(model: model, perform: perform)
                AdjustmentsPanel(model: model, perform: perform)
            }
        }
        .scrollIndicators(.never)
    }
}
