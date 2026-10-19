// DevelopInspector.swift: the inspector's Develop tab. Develop is not
// connected yet, so it says so in an EmptyStateView; while a crop draft is
// set it hosts CropInspector with the window's crop controls
// (`\.libraryCrop`, crop CR-6). It takes the catalog and the window's menu
// for the Develop actions to come. Values in, closures out; it never writes
// LibraryCatalog.
import LibraryModel
import SuiteUI
import SwiftUI

struct DevelopInspector: View {
    let model: LibraryCatalog
    /// The window's menu, whose actions the Develop tab calls.
    let menu: LibraryMenu
    let cropDraft: CropSettings?
    @Environment(\.libraryCrop) private var crop

    var body: some View {
        if cropDraft != nil {
            CropInspector(crop: crop)
        } else {
            EmptyStateView(
                "Develop", systemImage: "slider.horizontal.3", message: "Develop isn't connected yet (develop).")
        }
    }
}
