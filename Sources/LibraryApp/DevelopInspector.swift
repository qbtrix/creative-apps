// DevelopInspector.swift: the inspector's Develop tab. Develop is not
// connected yet, so it says so in an EmptyStateView; while a crop draft is
// set it hosts CropInspector. Values in; it never writes LibraryCatalog.
import LibraryModel
import SuiteUI
import SwiftUI

struct DevelopInspector: View {
    let cropDraft: CropSettings?

    var body: some View {
        if let cropDraft {
            CropInspector(cropDraft: cropDraft)
        } else {
            EmptyStateView(
                "Develop", systemImage: "slider.horizontal.3", message: "Develop isn't connected yet (develop).")
        }
    }
}
