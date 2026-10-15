// LibraryInspector.swift: the Library window's inspector: the selected
// photos' MetadataInspector or else the selected collection's SurfaceCard.
// Values in, closures out: it reads LibraryCatalog and hands each metadata
// edit to the closure LibraryWindow gives it; it never writes its state.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryInspector: View {
    let model: LibraryCatalog
    var onStar: @MainActor (Int) -> Void = { _ in }
    var onFlag: @MainActor (PhotoFlag) -> Void = { _ in }
    var onLabel: @MainActor (PhotoLabel?) -> Void = { _ in }

    var body: some View {
        if let metadata = model.selectedMetadata {
            MetadataInspector(metadata: metadata, onStar: onStar, onFlag: onFlag, onLabel: onLabel)
        } else if let collection = model.selectedCollection {
            SurfaceCard(title: collection.name, detail: "\(collection.count) photos")
        }
    }
}
