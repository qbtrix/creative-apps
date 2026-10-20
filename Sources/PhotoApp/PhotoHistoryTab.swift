// PhotoHistoryTab.swift: the History tab of a Photo window's inspector
// (history-panel PH-2): SuiteUI's HistoryPanel on the Model's listing ("Open"
// or "New Image", then every step, the current one marked). A click on a row
// asks the window to jump there (`HistoryIntent.jump`). Values in, intents out.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoHistoryTab: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        HistoryPanel(listing: model.historyListing) { perform(.history(.jump($0))) }
    }
}
