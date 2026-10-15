// LibraryShellSnapshots.swift: the spine's five shell states in Light and
// Dark (QB-V5): the empty catalog with Import Folder… disabled, the damaged
// and the newer catalog notices, the "Preview data" pill under the grid on
// the fakes, and the inspector with nothing selected. Writes
// library-empty-import, library-notice-damaged, library-notice-newer,
// library-preview-data and library-inspector-none, each -{light,dark}.png.
// macOS only.
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
        #expect(damaged.notice?.isError == true)
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

    /// The notice row sits on top of the content, as in the window.
    private func topAligned(_ view: some View) -> some View {
        view.frame(width: 1440, height: 900, alignment: .top)
    }

    /// The grid with the status bar under it, the way LibraryWindow stacks
    /// them on preview data. ImageRenderer drops the grid's ScrollView, so the
    /// grid is clipped to the space above the bar.
    private func previewData(_ model: LibraryCatalog) -> some View {
        VStack(spacing: 0) {
            LibraryBrowser(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            LibraryStatusBar(model: model)
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
