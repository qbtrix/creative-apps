// PhotoHistoryTab.swift: the History tab of a Photo window's inspector
// (history-panel PH-2, PH-3): SuiteUI's HistoryPanel on the Model's listing
// ("Open" or "New Image", then every step, the current one marked). The
// listing is read from the Model on every body, so an undo, a redo or a jump
// moves the current row and dims the rows past it; the panel brings its
// keyboard selection back to the current row when the listing changes. A
// click on a row, or Return on the selected one, asks the window to jump there
// once (`HistoryIntent.jump`). Values in, intents out.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct PhotoHistoryTab: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    /// The steps the tab lists, as the Model has them now.
    var listing: HistoryListing { model.historyListing }

    /// The panel over `listing`; each click or Return sends one jump.
    var panel: HistoryPanel {
        HistoryPanel(listing: listing) { jump(to: $0) }
    }

    /// Asks the window for the state after `index` steps (0 is the base).
    func jump(to index: Int) {
        perform(.history(.jump(index)))
    }

    var body: some View {
        panel
    }
}
