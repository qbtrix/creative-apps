// LibraryInspector.swift: the Library window's inspector: Info and Develop
// tabs on SegmentedTabs. Info shows the selected photos' MetadataInspector or
// else an InspectorHeader with the selected collection's name and photo
// count. Develop shows DevelopInspector. Which tab shows is presentation
// state kept here; values in, closures out: it reads LibraryCatalog and hands
// each metadata edit to the closure LibraryWindow gives it.
import LibraryModel
import SuiteUI
import SwiftUI

enum LibraryInspectorTab: Hashable, Sendable {
    case info, develop
}

struct LibraryInspector: View {
    let model: LibraryCatalog
    var onStar: @MainActor (Int) -> Void = { _ in }
    var onFlag: @MainActor (PhotoFlag) -> Void = { _ in }
    var onLabel: @MainActor (PhotoLabel?) -> Void = { _ in }
    @State private var tab = LibraryInspectorTab.info

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SegmentedTabs(
                "Inspector",
                tabs: [InspectorOption(id: .info, title: "Info"), InspectorOption(id: .develop, title: "Develop")],
                selection: tab, onChange: { tab = $0 })
                .libraryControl(id: "library.inspector.tabs", enabled: true, help: nil)
            if tab == .develop {
                DevelopInspector(cropDraft: model.cropDraft)
            } else if let metadata = model.selectedMetadata {
                MetadataInspector(metadata: metadata, onStar: onStar, onFlag: onFlag, onLabel: onLabel)
            } else if let collection = model.selectedCollection {
                InspectorHeader(collection.name, details: ["\(collection.count) photos"])
            }
        }
    }
}
