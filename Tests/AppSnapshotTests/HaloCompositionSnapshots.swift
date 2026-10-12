// HaloCompositionSnapshots.swift: the New Composition sheet with an invalid
// width, so its problem line shows and Create is disabled, in Light and Dark.
// Writes halo-new-comp-sheet-light.png and halo-new-comp-sheet-dark.png.
// macOS only.
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloCompositionSnapshots {
    @Test func newCompositionSheet() throws {
        var settings = HaloProject().suggestedSettings
        settings.width = 0
        try snapshot(NewCompositionSheet(settings: settings), name: "halo-new-comp-sheet-light", scheme: .light)
        try snapshot(NewCompositionSheet(settings: settings), name: "halo-new-comp-sheet-dark", scheme: .dark)
    }
}
