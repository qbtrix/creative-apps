// LibraryInspector.swift: the Library window's inspector: one InspectorHeader
// (`library.inspector.header`, the catalog's inspectorHeader: the collection's
// name and photo count with nothing selected, one photo's name, Captured, Size
// and Kind, or several photos' count and capture span), then SuiteUI's
// HistogramView of the loupe render (`library.develop.histogram`, valued with
// the render's mean, and saying why while it has no bins), pinned above both
// tabs, then Info and Develop
// tabs on SegmentedTabs (`library.inspector.tabs`, its segments
// `library.inspector.info` and `library.inspector.develop`, #291). Info shows the cull targets' MetadataInspector (the
// loupe photo in the loupe, else the selected photos) or nothing. Develop
// shows DevelopInspector with the catalog and the window's menu. Which tab
// shows is presentation state kept here; values in, closures out: it reads
// LibraryCatalog and hands each metadata edit to the closure LibraryWindow
// gives it. `utcOffset` is the local offset the header's and Taken's dates
// use; snapshots pass 0. Under the metadata, Info's Camera section shows the
// selection's CameraRow.rows (the catalog's selectedCameraRows) in
// CameraField order, each row one element `library.metadata.camera.<field>`
// whose value is its text, or "No camera details" when no photo has any
// (metadata-more MD-8). Nothing selected shows no Camera section.
import LibraryModel
import SuiteUI
import SwiftUI

enum LibraryInspectorTab: Hashable, Sendable {
    case info, develop
}

struct LibraryInspector: View {
    let model: LibraryCatalog
    /// The window's menu (LibraryMenu.disabled outside one), passed to the Develop tab.
    var menu = LibraryMenu()
    var onStar: @MainActor (Int) -> Void = { _ in }
    var onFlag: @MainActor (PhotoFlag) -> Void = { _ in }
    var onLabel: @MainActor (PhotoLabel?) -> Void = { _ in }
    var utcOffset = TimeZone.current.secondsFromGMT()
    @State private var tab = LibraryInspectorTab.info

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HistogramView(
                model.toneHistogram, emptyMessage: model.histogramEmptyMessage, value: model.histogramValue,
                id: DevelopInspector.histogramID)
            .padding(.horizontal, SuiteSpacing.m)
            .padding(.vertical, SuiteSpacing.s)
            // SegmentedTabs identifies the switch and each segment and lists them in suite.controls; an id
            // on this multi-element view would copy onto every element in it (swiftui-rules 7).
            SegmentedTabs("Inspector", tabs: Self.tabs, selection: tab, id: Self.tabsID, onChange: { tab = $0 })
                .transformPreference(LibraryControlsKey.self) {
                    $0.append(ControlEntry(id: Self.tabsID, enabled: true, reason: nil))
                }
            if tab == .develop {
                DevelopInspector(model: model, menu: menu, cropDraft: model.cropDraft)
            } else if let metadata = model.selectedMetadata {
                MetadataInspector(metadata: metadata, onStar: onStar, onFlag: onFlag, onLabel: onLabel)
                camera
            }
        }
    }

    /// The selection's camera rows, or "No camera details" when no photo has any.
    private var camera: some View {
        let rows = model.selectedCameraRows
        return InspectorSection("Camera") {
            if rows.isEmpty {
                InspectorNote(Self.noCameraText, identifier: Self.noCameraID)
            } else {
                ForEach(rows, id: \.field) { row in
                    let text = Self.text(row.value, utcOffset: utcOffset)
                    InspectorRow(row.field.rawValue) {
                        Text(verbatim: text)
                            .font(SuiteFont.inspectorValue)
                            .foregroundStyle(SuiteColor.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    // One element per row, so the identifier lands on it alone (swiftui-rules 7).
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: row.field.rawValue))
                    .accessibilityValue(Text(verbatim: text))
                    .accessibilityIdentifier(MetadataInspectorID.camera(row.field))
                }
            }
        }
    }

    /// A row's text: its own, or Taken's date (one moment) or day span (several).
    nonisolated private static func text(_ value: CameraRowValue, utcOffset: Int) -> String {
        switch value {
        case .text(let text): return text
        case .dates(let first, let last):
            let zone = TimeZone(secondsFromGMT: utcOffset) ?? .current
            guard first != last else {
                return first.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: zone))
            }
            let day = Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: zone)
            let (from, to) = (first.formatted(day), last.formatted(day))
            return from == to ? from : from + " – " + to
        }
    }

    /// What the Camera section says when no selected photo has camera details.
    nonisolated static let noCameraText = "No camera details"

    /// That note's accessibility identifier.
    nonisolated static let noCameraID = "library.metadata.camera.none"

    /// The one title above the tabs, with the selection's facts.
    private var header: some View {
        let facts = model.inspectorHeader(utcOffset: utcOffset)
        return InspectorHeader(facts.title, facts: facts.facts.map { InspectorFact($0.label, $0.value) })
            .accessibilityIdentifier(Self.headerID)
    }

    /// The header's accessibility identifier, as J12 looks it up.
    static let headerID = "library.inspector.header"

    /// The tab switch's accessibility identifier.
    nonisolated static let tabsID = "library.inspector.tabs"

    /// The Info and Develop tabs, each segment with its own `library.inspector.<tab>` identifier. J11 clicks
    /// the identified controls in id order from Info: develop, info, then the switch, so each click changes the tab.
    nonisolated static let tabs = [
        InspectorOption(id: LibraryInspectorTab.info, title: "Info", identifier: "library.inspector.info"),
        InspectorOption(id: LibraryInspectorTab.develop, title: "Develop", identifier: "library.inspector.develop"),
    ]
}
