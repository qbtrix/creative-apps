// PhotoFilterAdapterTests.swift: Photo's live filter sheet (PhotoFilterSheetAdapter) on an open
// image. With Preview on, the sheet holds the preview's slot from its first frame, so it doesn't
// grow when the picture arrives (it is made off the main actor after a debounce). Writes
// photo-filter-live-light/dark.png: the live sheet before its picture arrives. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor @Suite struct PhotoFilterAdapterTests {
    private func adapter(preview: Bool) throws -> PhotoFilterSheetAdapter {
        var draft = try #require(FilterSheetDraft("gaussian-blur"))
        draft.setPreview(preview)
        return PhotoFilterSheetAdapter(model: try PhotoWorkspace.fixture(.layered), draft: draft, perform: { _ in })
    }

    @Test func previewSlotIsThereBeforeThePicture() throws {
        let on = NSHostingView(rootView: try adapter(preview: true)).fittingSize.height
        let off = NSHostingView(rootView: try adapter(preview: false)).fittingSize.height
        #expect(on - off >= SuiteSize.inspectorWidth.ideal, "the sheet is \(on) with Preview on, \(off) off")
    }

    @Test func liveSheet() throws {
        for scheme in [ColorScheme.light, .dark] {
            let view = try adapter(preview: true).background(SuiteColor.panel)
            try snapshot(view, name: "photo-filter-live-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
#endif
