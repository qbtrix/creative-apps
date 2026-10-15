// LibraryShellSnapshots.swift: the spine's five shell states in Light and
// Dark (QB-V5): the empty catalog with Import Folder… disabled, the damaged
// and the newer catalog notices, the "Preview data" pill under the grid on
// the fakes, and the inspector with nothing selected. Writes
// library-empty-import, library-notice-damaged, library-notice-newer,
// library-preview-data and library-inspector-none, each -{light,dark}.png.
// macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryShellSnapshots {
    @Test func shellStates() throws {
        let empty = LibraryCatalog()
        #expect(empty.isEmpty && empty.notice == nil)
        var damaged = LibraryCatalog()
        damaged.catalogState = .damaged
        #expect(damaged.notice?.isError == false)
        #expect(damaged.emptyState(importReason: nil).title != "No Photos")
        var newer = LibraryCatalog()
        newer.catalogState = .newer(version: 9)
        #expect(newer.notice?.message == CatalogFileState.newer(version: 9).message)
        var samples = LibraryCatalog()
        samples.loadSamples()
        #expect(samples.services.isPreview && samples.selection.isEmpty)
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(LibraryBrowser(model: empty), name: "library-empty-import-\(suffix)", scheme: scheme)
            try snapshot(
                topAligned(LibraryBrowser(model: damaged)), name: "library-notice-damaged-\(suffix)", scheme: scheme)
            try snapshot(
                topAligned(LibraryBrowser(model: newer)), name: "library-notice-newer-\(suffix)", scheme: scheme)
            try snapshot(previewData(samples), name: "library-preview-data-\(suffix)", scheme: scheme)
            try snapshot(inspector(samples), name: "library-inspector-none-\(suffix)", scheme: scheme)
        }
    }

    /// Geometry: on preview data the status bar sits inside the 1440x900
    /// frame, at its bottom, over the grid. The bottom band of the stacked
    /// view matches the bar drawn alone at the bottom of the same frame;
    /// before the fix the grid overflowed and the band showed thumbnails.
    @Test func previewDataShowsTheStatusBarInsideTheFrame() throws {
        var samples = LibraryCatalog()
        samples.loadSamples()
        let barHeight = NSHostingView(rootView: LibraryStatusBar(model: samples)).fittingSize.height
        #expect(barHeight > 0 && barHeight < 100, "status bar height \(barHeight)")
        let stacked = try #require(render(previewData(samples), scheme: .light))
        let alone = try #require(render(
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LibraryStatusBar(model: samples).fixedSize(horizontal: false, vertical: true)
            }.frame(width: 1440, height: 900), scheme: .light))
        let row = 900 - max(1, Int(barHeight / 2))
        var differing = 0
        for x in stride(from: 0, to: 1440, by: 4) {
            guard let a = stacked.colorAt(x: x, y: row)?.usingColorSpace(.sRGB),
                  let b = alone.colorAt(x: x, y: row)?.usingColorSpace(.sRGB) else { continue }
            let delta = abs(a.redComponent - b.redComponent) + abs(a.greenComponent - b.greenComponent)
                + abs(a.blueComponent - b.blueComponent)
            if delta > 0.06 { differing += 1 }
        }
        #expect(differing <= 18, "the bottom band differs from the status bar at \(differing) of 360 samples")
    }

    /// The notice row sits on top of the content, as in the window.
    private func topAligned(_ view: some View) -> some View {
        view.frame(width: 1440, height: 900, alignment: .top)
    }

    /// The grid with the status bar under it, the way LibraryWindow stacks
    /// them on preview data. The grid may lay out at its full height, so it is
    /// bounded (minHeight 0), top-aligned and clipped to the space above the bar.
    private func previewData(_ model: LibraryCatalog) -> some View {
        VStack(spacing: 0) {
            LibraryBrowser(model: model)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
            LibraryStatusBar(model: model).fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 1440, height: 900)
    }

    private func inspector(_ model: LibraryCatalog) -> some View {
        LibraryInspector(model: model)
            .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
    }
}
