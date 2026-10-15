// LibraryExportSheet.swift: the export sheet, a stub until the export feature
// fills it. LibraryWindow presents it while `exportState != .idle`; nothing
// sets that in wave 1. Cancel dismisses it.
import SuiteUI
import SwiftUI

struct LibraryExportSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Text("Export").font(SuiteFont.headline)
            Form {
                Text("Export isn't connected yet.")
                    .foregroundStyle(SuiteColor.secondaryText)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("library.export.cancel")
            }
        }
        .padding(SuiteSpacing.l)
        .frame(width: SuiteSize.inspectorWidth.max)
    }
}
