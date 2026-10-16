// FlareLibraryPanel.swift: the inspector's Library tab. Until the library
// feature (F12a) lands it says so in an empty state; it only reads `model`.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareLibraryPanel: View {
    let model: FlareWorkspace
    let perform: @MainActor (FlareIntent) -> Void

    var body: some View {
        EmptyStateView(
            "Not built yet", systemImage: "books.vertical",
            message: "Symbols and swatches arrive with the library (F12a).")
    }
}
