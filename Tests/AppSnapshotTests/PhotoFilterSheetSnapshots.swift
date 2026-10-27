// PhotoFilterSheetSnapshots.swift (adjust-everywhere AJ-3): Gaussian Blur at its start, OK off on the
// pending target: photo-filter-sheet-{light,dark}.png. macOS only.
#if canImport(AppKit)
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor @Suite struct PhotoFilterSheetSnapshots {
    @Test func screens() throws {
        let draft = try #require(FilterSheetDraft("gaussian-blur"))
        #expect(draft.preview)
        for scheme in [ColorScheme.light, .dark] {
            let sheet = FilterSheet(draft: draft, target: PendingAdjustTarget())
                .background(SuiteColor.panel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            try snapshot(sheet, name: "photo-filter-sheet-\(scheme.name)", scheme: scheme)
        }
    }
}
#endif
