// PhotoHistoryTab.swift: the History tab of a Photo window's right panel. A
// stub for now: it takes the model and the intent sink like its sibling tabs
// but draws nothing, and no panel tab shows it until PV-4 adds the tab and
// its list. Values in, intents out.
import PhotoModel
import SwiftUI

struct PhotoHistoryTab: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        EmptyView()
    }
}
