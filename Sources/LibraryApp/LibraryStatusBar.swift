// LibraryStatusBar.swift: the row under the Library window's content, the
// grid's and the loupe's (status-and-layout SL-4). It draws LibraryCatalog's
// `statusRow` through ViewerStatusBar: the zoom pill, the size pill (the
// photo count in the grid, the loupe photo's pixel size), then one pill per
// row entry: the selection and cell size in the grid, the loupe's Fit and
// place, and the import, render, save and Preview data pills, each
// `library.status.<id>` with its help as tooltip and accessibility hint, and
// a warning entry in warning colors. With no row (an empty live catalog) it
// draws nothing. ViewerStatusBar can't hide its zoom pill yet (#1184), so a
// row without a zoom shows the fit scale the loupe measured, or 100% in the
// grid.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryStatusBar: View {
    let model: LibraryCatalog
    /// The fit scale the loupe measured, which Zoom to Fit draws at.
    var fitScale = 1.0

    var body: some View {
        if let row = model.statusRow {
            ViewerStatusBar(zoom: row.zoom ?? (model.loupeItem == nil ? 1 : fitScale), size: row.size) {
                ForEach(row.pills) { pill in
                    let face = Text(pill.text)
                        .help(pill.help)
                        .accessibilityHint(pill.help)
                        .accessibilityIdentifier(Self.identifier(pill))
                    if pill.style == .warning {
                        face.statusPill(.warning)
                    } else {
                        face.statusPill(.plain)
                    }
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
}
