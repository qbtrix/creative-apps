// DesignCommandPathTests.swift (command-state CS-13): the ids Design's bare controls must run once they move onto
// commands (CS-14): File > Export… and View's Zoom In, Zoom Out, Fit Page and Zoom to Selection. Each is in the
// catalog with a params schema its example meets, runs headless, is off with the window's reason, and Export's
// params reach its run. Fails when a control's action has no command. Linux-safe.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignCommandPathTests {
    /// The control each id stands for, as the menus title it today.
    static let controls: [(id: String, control: String)] = [
        ("file.export", "Export…"), ("view.zoom-in", "Zoom In"), ("view.zoom-out", "Zoom Out"),
        ("view.fit", "Fit Page"), ("view.zoom-to-selection", "Zoom to Selection"),
    ]

    static var oneLayer: DesignWorkspace { var w = DesignFixtures.cards; w.selectItem("node-2"); return w }

    @Test(arguments: controls.map(\.id))
    func isInTheCatalogWithASchemaAndRunsHeadless(id: String) throws {
        let spec = try #require(DesignWorkspace.catalog.spec(id), "\(id) is not in Design's catalog")
        #expect(spec.title == Self.controls.first { $0.id == id }?.control)
        #expect(spec.params.validate(spec.example).isEmpty, "\(id)'s example breaks its schema")
        #expect(DesignWorkspace.catalog.describe(id) != nil)
        var doc = DesignHeadless(Self.oneLayer)
        let before = try doc.save()
        let outcome = try DesignHeadless.catalog.run(id, params: spec.example, on: &doc)
        #expect(outcome.undoStep == nil, "\(id) is not an edit")
        #expect(try doc.save() == before, "\(id) changed the file")
    }

    /// No file: every control is off with the toolbar's reason; Zoom to Selection with nothing selected is off with
    /// the View menu's reason, and on with a layer selected.
    @Test func reasonWhenUnavailable() {
        let none = DesignWorkspace(), cards = DesignFixtures.cards
        for (id, _) in Self.controls {
            #expect(DesignWorkspace.catalog.availability(id, on: none).why == DesignToolbarItem.noFile
                    || (id == "view.zoom-to-selection" && DesignWorkspace.catalog.availability(id, on: none).why == none.zoomToSelectionHelp),
                    "\(id) with no file")
        }
        for id in ["file.export", "view.zoom-in", "view.zoom-out", "view.fit"] {
            #expect(DesignWorkspace.catalog.availability(id, on: cards).why == nil, "\(id) with a file")
        }
        #expect(DesignWorkspace.catalog.availability("view.zoom-to-selection", on: cards).why == cards.zoomToSelectionHelp)
        #expect(cards.zoomToSelectionHelp != nil)
        #expect(DesignWorkspace.catalog.availability("view.zoom-to-selection", on: Self.oneLayer).why == nil)
    }

    /// Export's format, scale and scope each change what it plans: the files' names, sizes and which layers.
    @Test func paramsReachRun() throws {
        func files(_ format: String, _ scale: Int, _ scope: String) throws -> JSONValue {
            var w = Self.oneLayer
            let params = JSONValue.object(["format": .string(format), "scale": .number(Double(scale)), "scope": .string(scope)])
            return try DesignWorkspace.catalog.run("file.export", params: params, on: &w).result
        }
        func one(_ name: String, _ width: Double, _ height: Double) -> JSONValue {
            .object(["files": .array([.object(["name": .string(name), "width": .number(width), "height": .number(height)])])])
        }
        let png = try files("png", 1, "frame")
        #expect(png == one("Desktop.png", 1440, 1024))
        #expect(try files("svg", 1, "frame") == one("Desktop.svg", 1440, 1024))
        #expect(try files("png", 2, "frame") == one("Desktop.png", 2880, 2048))
        #expect(try files("png", 1, "selection") != png, "scope reached the run")
        #expect(throws: CatalogError.self) {
            var w = Self.oneLayer
            let tiff = JSONValue.object(["format": .string("tiff"), "scale": .number(1), "scope": .string("frame")])
            _ = try DesignWorkspace.catalog.run("file.export", params: tiff, on: &w)
        }
    }

    /// A refusal reaches the CLI and MCP in words: Selection with nothing selected says "Select a layer first.",
    /// not the refusal's case name.
    @Test func aRefusalFailsInWords() {
        var w = DesignFixtures.cards
        let params = JSONValue.object(["format": .string("pdf"), "scale": .number(1), "scope": .string("selection")])
        #expect(throws: CatalogError.failed(id: "file.export", message: "Select a layer first.")) {
            _ = try DesignWorkspace.catalog.run("file.export", params: params, on: &w)
        }
    }

    /// Zoom to Selection reports the rect it would show: the selection's framing.
    @Test func zoomToSelectionReportsItsRect() throws {
        var w = Self.oneLayer
        let rect = try #require(w.zoomToSelectionRect)
        let result = try DesignWorkspace.catalog.run("view.zoom-to-selection", params: .object([:]), on: &w).result
        #expect(result == .object(["x": .number(rect.x), "y": .number(rect.y), "width": .number(rect.width), "height": .number(rect.height)]))
    }
}
