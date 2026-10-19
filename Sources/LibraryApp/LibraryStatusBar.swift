// LibraryStatusBar.swift: the row under the Library window's content, the
// grid's and the loupe's (status-and-layout SL-4). It draws LibraryCatalog's
// `statusRow` through ViewerStatusBar: the zoom pill, the size pill (the
// photo count in the grid, the loupe photo's pixel size), then one pill per
// row entry: the selection and cell size in the grid, and the import, render,
// save and Preview data pills, each `library.status.<id>` with its help as
// tooltip and accessibility hint. The loupe's place is its HUD's. A
// `.selected` entry draws as an on toggle, a warning entry in warning colors
// and an error entry (a failed save or render) in error colors. With no row (an empty live catalog) it draws nothing.
// The identifier and help come last on each trailing view, so they name the
// pill once ViewerStatusBar makes the capsule one element (#3197).
// A row without a zoom (the grid) draws no zoom pill; at Fit the loupe's
// measured fit scale is the one zoom pill.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryStatusBar: View {
    let model: LibraryCatalog
    /// The fit scale the loupe measured, which Zoom to Fit draws at.
    var fitScale = 1.0

    var body: some View {
        if let row = model.statusRow {
            ViewerStatusBar(zoom: row.shownZoom(fitScale: fitScale), size: row.size) {
                ForEach(row.pills) { pill in
                    Text(pill.text)
                        .statusPill(Self.style(pill))
                        .help(pill.help)
                        .accessibilityHint(pill.help)
                        .accessibilityIdentifier(Self.identifier(pill))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("library.status")
        }
    }

    /// The pill's accessibility identifier: `library.status.<id>`.
    nonisolated static func identifier(_ pill: LibraryStatusPill) -> String {
        "library.status.\(pill.id)"
    }

    /// How ViewerStatusBar draws the pill.
    nonisolated static func style(_ pill: LibraryStatusPill) -> StatusPillStyle {
        switch pill.style {
        case .plain: .plain
        case .selected: .toggle(isOn: true)
        case .warning: .warning
        case .error: .error
        }
    }
}
