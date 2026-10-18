// LibraryExportSheet.swift: the export sheet, a stub until the export feature
// fills it. LibraryWindow presents it while `exportState != .idle`; nothing
// sets that in wave 1. Cancel dismisses it.
import SuiteUI
import SwiftUI

struct LibraryExportSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SuiteSheet("Export", cancelIdentifier: "library.export.cancel", onCancel: { dismiss() }) {
            Form {
                Text("Export isn't connected yet.")
                    .foregroundStyle(SuiteColor.secondaryText)
            }
        }
    }
}
