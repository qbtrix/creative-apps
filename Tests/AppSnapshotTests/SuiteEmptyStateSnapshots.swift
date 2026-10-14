// SuiteEmptyStateSnapshots.swift: SuiteUI's EmptyStateView with its one
// action, in Light and Dark: once available (a prominent, enabled button) and
// once unavailable (the same button disabled, its reason as the tooltip).
// Writes suiteui-empty-state-available-{light,dark}.png and
// suiteui-empty-state-unavailable-{light,dark}.png. macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteEmptyStateSnapshots {
    @Test func emptyStateAction() throws {
        let available = ToolbarAction("Import Photos", systemImage: "square.and.arrow.down")
        let unavailable = ToolbarAction(
            "Import Photos", systemImage: "square.and.arrow.down",
            unavailableHelp: "Importing needs a catalog folder; choose one in Settings first.")
        #expect(available.isEnabled)
        #expect(!unavailable.isEnabled)
        #expect(unavailable.help == "Importing needs a catalog folder; choose one in Settings first.")
        let states = [("available", available), ("unavailable", unavailable)]
        for (state, action) in states {
            let view = EmptyStateView(
                "No Photos", systemImage: "photo.on.rectangle",
                message: "Import photos to start your catalog.", action: action)
            for scheme in [ColorScheme.light, .dark] {
                let suffix = scheme == .dark ? "dark" : "light"
                try snapshot(view, name: "suiteui-empty-state-\(state)-\(suffix)", scheme: scheme)
            }
        }
    }
}
