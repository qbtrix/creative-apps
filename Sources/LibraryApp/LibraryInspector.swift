// LibraryInspector.swift: the Library window's inspector: the selected
// photos' MetadataInspector or else the selected collection's SurfaceCard.
// It reads LibraryCatalog and calls its methods; it never writes its state.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryInspector: View {
    let model: LibraryCatalog

    var body: some View {
        if let metadata = model.selectedMetadata {
            MetadataInspector(
                metadata: metadata, onStar: { model.clickStar($0) }, onFlag: { model.setFlag($0) },
                onLabel: { model.setLabel($0) })
        } else if let collection = model.selectedCollection {
            SurfaceCard(title: collection.name, detail: "\(collection.count) photos")
        }
    }
}
