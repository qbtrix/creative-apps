// SuiteCommandCatalogSnapshots.swift (command-catalog CC-9): the gallery's
// `command-catalog` page in Light and Dark. On the empty document "Remove
// Rectangle" and "Move Rectangle" are disabled with their why-not shown as
// help; writes suiteui-command-catalog-{light,dark}.png. After Add Rectangle
// the document holds one rect and the Edit row reads "Undo Add Rectangle";
// writes suiteui-command-catalog-ran-{light,dark}.png.
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteCommandCatalogSnapshots {
    @Test func emptyDocument() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(GalleryCommandCatalogPage(), name: "suiteui-command-catalog-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func afterAddRectangle() throws {
        var doc = FakeCanvasDocument()
        #expect(GalleryCommandCatalog.run("rect.add", on: &doc) == "rect.add: Add Rectangle")
        #expect(GalleryCommandCatalog.undoTitle(doc) == "Undo Add Rectangle")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(GalleryCommandCatalogPage(document: doc), name: "suiteui-command-catalog-ran-\(scheme.name)", scheme: scheme)
        }
    }
}
