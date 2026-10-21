// MenuCommandCatalogTests.swift (command-catalog CC-9): a MenuCommand built
// from a kernel CommandSpec takes its title from the spec, is enabled exactly
// when the spec is available on the target, and its help is the spec's
// summary or, disabled, "<title>: <why>". Checked over the fake catalog on an
// empty document and on the fixture, plus the gallery page's rows and Edit
// row title. macOS only.
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct MenuCommandCatalogTests {
    private let catalog = FakeCanvasDocument.catalog

    private func item(_ id: String, on doc: FakeCanvasDocument) throws -> MenuCommand {
        MenuCommand(try #require(catalog.spec(id)), on: doc) {}
    }

    @Test func titleEnabledAndHelpFromTheSpec() throws {
        let empty = FakeCanvasDocument()
        let add = try item("rect.add", on: empty)
        #expect(add.title == "Add Rectangle" && add.isEnabled)
        #expect(add.help == "Adds a rectangle with the given frame and selects it.")
        let remove = try item("rect.remove", on: empty)
        #expect(remove.title == "Remove Rectangle" && !remove.isEnabled)
        #expect(remove.help == "Remove Rectangle: Select a rectangle first.")
        var locked = FakeCanvasDocument.fixture
        _ = try catalog.run("rect.select", params: .object(["id": .number(2)]), on: &locked)
        let move = try item("rect.move", on: locked)
        #expect(!move.isEnabled && move.help == "Move Rectangle: Unlock Rect 2 first.")
        let free = try item("rect.move", on: .fixture)
        #expect(free.isEnabled && free.help.hasPrefix("Moves the selected rectangle"))
    }

    @Test func itKeepsSymbolShortcutAndPerform() throws {
        var ran = 0
        let spec = try #require(catalog.spec("rect.add"))
        let item = MenuCommand(spec, on: FakeCanvasDocument(), systemImage: "plus", shortcut: KeyboardShortcut("r")) { ran += 1 }
        #expect(item.systemImage == "plus" && item.shortcut == KeyboardShortcut("r"))
        item.perform()
        #expect(ran == 1)
        let named = MenuCommand(spec, on: FakeCanvasDocument(), title: "Add a Box") {}
        #expect(named.title == "Add a Box" && named.help == spec.summary)
    }

    @Test func disabledHasWhy() throws {
        for doc in [FakeCanvasDocument(), .fixture] {
            for id in catalog.ids {
                let why = catalog.availability(id, on: doc).why
                let built = try item(id, on: doc)
                #expect(built.isEnabled == (why == nil), "\(id)")
                if let why { #expect(built.help == "\(built.title): \(why)", "\(id) hides its why-not") }
            }
        }
    }

    @Test func galleryRowsAndUndoTitle() throws {
        #expect(GalleryCommandCatalog.rows.map(\.id)
                == ["rect.add", "rect.move", "rect.remove", "rect.select", "rect.list", "doc.export-json"])
        var doc = FakeCanvasDocument()
        #expect(GalleryCommandCatalog.undoTitle(doc) == "Undo")
        #expect(GalleryCommandCatalog.run("rect.add", on: &doc) == "rect.add: Add Rectangle")
        #expect(doc.rects.count == 1 && GalleryCommandCatalog.undoTitle(doc) == "Undo Add Rectangle")
        #expect(GalleryCommandCatalog.run("rect.list", on: &doc) == "rect.list: ran")
        var empty = FakeCanvasDocument()
        #expect(GalleryCommandCatalog.run("rect.remove", on: &empty) == "rect.remove is unavailable: Select a rectangle first.")
        #expect(empty.rects.isEmpty)
    }
}
