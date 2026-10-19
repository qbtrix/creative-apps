// LibraryInspector.swift: the Library window's inspector: one InspectorHeader
// (`library.inspector.header`, the catalog's inspectorHeader: the collection's
// name and photo count with nothing selected, one photo's name, Captured, Size
// and Kind, or several photos' count and capture span), then Info and Develop
// tabs on SegmentedTabs. Info shows the cull targets' MetadataInspector (the
// loupe photo in the loupe, else the selected photos) or nothing. Develop
// shows DevelopInspector. Which tab shows is presentation state kept here;
// values in, closures out: it reads LibraryCatalog and hands each metadata
// edit to the closure LibraryWindow gives it. `utcOffset` is the local
// offset the header's dates use; snapshots pass 0.
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
    var utcOffset = TimeZone.current.secondsFromGMT()
    @State private var tab = LibraryInspectorTab.info

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            SegmentedTabs(
                "Inspector",
                tabs: [InspectorOption(id: .info, title: "Info"), InspectorOption(id: .develop, title: "Develop")],
                selection: tab, onChange: { tab = $0 })
                .libraryControl(id: "library.inspector.tabs", enabled: true, help: nil)
            if tab == .develop {
                DevelopInspector(cropDraft: model.cropDraft)
            } else if let metadata = model.selectedMetadata {
                MetadataInspector(metadata: metadata, onStar: onStar, onFlag: onFlag, onLabel: onLabel)
            }
        }
    }

    /// The one title above the tabs, with the selection's facts.
    private var header: some View {
        let facts = model.inspectorHeader(utcOffset: utcOffset)
        return InspectorHeader(facts.title, facts: facts.facts.map { InspectorFact($0.label, $0.value) })
            .accessibilityIdentifier(Self.headerID)
    }

    /// The header's accessibility identifier, as J12 looks it up.
    static let headerID = "library.inspector.header"
}
