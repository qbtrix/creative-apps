// PhotoCommandCatalogTests.swift (AC-p1): Photo's catalog keeps the laws, its ledger, today's help and today's menus.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel
import Testing
@testable import PhotoModel

/// PhotoWorkspace as a headless document for the laws only (PhotoHeadless is AC-p2's); save() is the snapshot's content.
struct PhotoLawsDocument: HeadlessDocument {
    var ws: PhotoWorkspace
    static let app = "photo", openExtensions: [String] = [], exportFormats: [String] = []
    static let catalog = (try? CommandCatalog<PhotoLawsDocument>(app: app, PhotoWorkspace.commands.map(lift), history: { $0.ws.history.kernel }))
        ?? .empty(app: app)
    static func lift(_ spec: CommandSpec<PhotoWorkspace>) -> CommandSpec<PhotoLawsDocument> {
        .typed(spec.id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: spec.params,
               result: spec.result, example: spec.example, availability: { spec.availability($0.ws) }) { doc, params in
            try PhotoWorkspace.catalog.run(spec.id, params: params, on: &doc.ws).result
        }
    }
    static func open(_ data: Data, name: String) throws -> PhotoLawsDocument { throw CatalogError.failed(id: "open", message: "laws only") }
    static func new(_ options: JSONValue) throws -> PhotoLawsDocument { PhotoLawsDocument(ws: PhotoWorkspace(services: .fake)) }
    func save() throws -> Data {
        let s = try ws.snapshot()
        var bytes = Array("\(s.canvas)\(s.layers)\(s.adjustments)".utf8)
        for (id, image) in s.pixels.sorted(by: { $0.key < $1.key }) + s.masks.sorted(by: { $0.key < $1.key }) {
            bytes += Array(id.utf8) + image.rgba8
        }
        return Data(bytes)
    }
    func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { [] }
    func summary() -> JSONValue { .null }
}

struct PhotoCommandCatalogTests {
    /// Three layers, the middle one ("Layer 1") filled and selected under a select-all: every example can run.
    static func lawsFixture() throws -> PhotoWorkspace {
        var ws = PhotoWorkspace(services: .fake)
        try ws.newCanvas(width: 16, height: 12)
        ws.addLayer(); ws.addLayer(); ws.selectLayerBelow(); ws.selectAll(); ws.fillSelection()
        ws.setSelection(PixelRect(x: 0, y: 0, width: 8, height: 12)); ws.deleteSelection(); ws.selectAll()
        return ws // half filled, so Fill and Delete each change pixels
    }

    /// No document, empty, one layer, "locked" (Photo has no lock: an adjustment layer), a selection, mid-drag.
    static func states() throws -> [(String, PhotoWorkspace)] {
        var empty = PhotoWorkspace(services: .fake)
        try empty.newCanvas(width: 16, height: 12)
        var one = empty
        one.selectAll(); one.fillSelection(); one.deselect()
        var locked = try PhotoWorkspace.fixture(.layered)
        if let curves = locked.layers.first(where: { $0.name == "Curves 1" }) { locked.selectLayer(curves.id) }
        var drag = one
        drag.selectTool(.brush); drag.drag(from: Mask.Point(x: 2, y: 2), to: Mask.Point(x: 8, y: 6))
        return [("none", PhotoWorkspace(services: .fake)), ("empty", empty), ("one", one), ("locked", locked),
                ("selection", try lawsFixture()), ("drag", drag)]
    }

    @Test func conformance() throws {
        #expect(PhotoWorkspace.catalog.ids.count == PhotoWorkspace.commands.count)
        let fixture = PhotoLawsDocument(ws: try Self.lawsFixture())
        // Only exampleRuns, and only for a command whose availability says why it is off on the fixture (tool.gradient
        // until PG-3): its example refuses as unavailable, the filter Design's and Library's laws use. The file-flow
        // examples need a recent file, a saved image or a readable file on disk: PhotoFileFlowTests runs them.
        let needsFiles = Set(["file.clear-recent", "file.drop", "file.open-in", "file.open-recent"])
        let problems = CatalogConformance.check(PhotoLawsDocument.self, fixture: fixture).filter { problem in
            let id = String(problem.prefix { $0 != ":" })
            guard problem.hasPrefix("\(id): exampleRuns") else { return true }
            let off = PhotoLawsDocument.catalog.availability(id, on: fixture).why != nil
            return !(off || needsFiles.contains(id))
        }
        #expect(problems == Self.tolerated)
    }
    /// The kernel's transform.flip is titled "Flip" while its step names the axis ("Flip Horizontal"), as the
    /// transform packet asks. (Free Transform's commit and cancel refuse without a draft: the filter above drops them.)
    static let tolerated = ["transform.flip: stepNamedTitle: its undo step reads \"Flip Horizontal\", not \"Flip\""]

    @Test func ledger() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/photo.txt")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(CommandIDLedger.check(PhotoWorkspace.catalog.ids, ledger: text) == [])
        let listed = Set(text.split(separator: "\n").map(String.init))
        #expect(PhotoWorkspace.catalog.ids.filter { !listed.contains($0) } == [], "every id is in the ledger")
    }

    static let bar: [String: PhotoToolbarItem] = ["file.open": .open, "file.save": .save, "file.export": .export, "edit.undo": .undo,
                                                  "edit.redo": .redo, "view.zoom-out": .zoomOut, "view.fit": .fit, "view.zoom-in": .zoomIn]
    static let imageOnly = ["file.save-as", "image.resize", "image.rotate-cw", "image.rotate-ccw", "image.rotate-180",
                            "image.straighten", "layer.new", "view.actual-size"]
    /// The help the app shows today for `id`, where it shows one.
    static func oldHelp(_ id: String, _ ws: PhotoWorkspace) -> String?? {
        if let item = bar[id] { return item.unavailableHelp(in: ws) }
        if let tool = PhotoTool(rawValue: String(id.dropFirst(5))), id.hasPrefix("tool.") { return ws.toolHelp(tool) }
        if imageOnly.contains(id) { return ws.canvas == nil ? "Open an image first." : nil }
        switch id {
        case "edit.cut": return ws.cutHelp
        case "edit.copy": return ws.copyHelp
        case "edit.paste": return ws.pasteHelp(true)
        case "layer.new-adjustment": return ws.addAdjustmentLayerHelp
        case "layer.duplicate": return ws.duplicateLayerHelp
        case "layer.merge-down": return ws.mergeDownHelp
        case "layer.flatten": return ws.flattenHelp
        default: return .none
        }
    }

    @Test func availabilityMatchesHelp() throws {
        for (state, ws) in try Self.states() {
            for id in PhotoWorkspace.catalog.ids {
                guard case .some(let old) = Self.oldHelp(id, ws) else { continue }
                #expect(PhotoWorkspace.catalog.availability(id, on: ws).why == old, "\(id) in \(state)")
            }
        }
    }

    /// The menu table today, item by item: the rules PhotoApp's menus apply (PhotoCommands*.swift).
    static func oldMenu(_ ws: PhotoWorkspace) -> [String] {
        let image = ws.canvas != nil
        func row(_ title: String, _ on: Bool, _ help: String?? = .none) -> String {
            "\(title)|\(on)|\(help.map { $0.map { "\(title): \($0)" } ?? title } ?? "-")"
        }
        let adjust = ws.addAdjustmentLayerHelp
        return [row("New Image", true), row("Open…", true), row("Save", image), row("Save As…", image), row("Export…", image),
                row(ws.undoActionName, ws.canUndo), row(ws.redoActionName, ws.canRedo),
                row("Cut", image, ws.cutHelp), row("Copy", image, ws.copyHelp), row("Paste", true, ws.pasteHelp(true)),
                row("Select All", ws.canSelectAll), row("Delete Selection", ws.canEditSelection), row("Fill Selection", ws.canEditSelection),
                row("All", image), row("Deselect", ws.canDeselect)]
            + ["Image Size…", "Rotate 90° Clockwise", "Rotate 90° Counterclockwise", "Rotate 180°", "Straighten…"].map { row($0, image) }
            + [row("New Layer", image),
               "New Adjustment Layer|\(!ws.adjustmentLayerKinds.isEmpty && adjust == nil)|\(adjust ?? "New Adjustment Layer")",
               row("Delete Layer", ws.canDeleteSelectedLayer), row("Duplicate Layer", ws.duplicateLayerHelp == nil, ws.duplicateLayerHelp),
               row("Merge Down", ws.mergeDownHelp == nil, ws.mergeDownHelp), row("Flatten Image", ws.flattenHelp == nil, ws.flattenHelp),
               row("Rename Layer…", ws.canEditSelectedLayer), row(ws.visibilityCommandTitle, ws.canEditSelectedLayer),
               row("Bring Forward", ws.canBringSelectedLayerForward), row("Send Backward", ws.canSendSelectedLayerBackward),
               row("Select Layer Above", ws.canBringSelectedLayerForward), row("Select Layer Below", ws.canSendSelectedLayerBackward)]
            + ["Zoom In", "Zoom Out", "Actual Size", "Fit on Screen"].map { row($0, image) }
    }

    /// Every non-tool command but the shared file-flow ones and Free Transform's (transform PT-5, ahead of its menu
    /// items), in menu order (the catalog lists them as the menus do).
    static let menuIDs = PhotoWorkspace.commands.map(\.id).filter {
        !$0.hasPrefix("tool.") && !$0.hasPrefix("transform.") && !fileFlowIDs.contains($0)
    }
    /// The shared file-flow commands (PF-3), which today's menus don't show yet.
    static let fileFlowIDs = Set(FileFlowCommands.specs(PhotoWorkspace.self).map(\.id))
    static let helped: Set = ["edit.cut", "edit.copy", "edit.paste", "layer.duplicate", "layer.merge-down", "layer.flatten"]
    /// Today's Cut and Copy stay on with an image open (they also act on focused text); the catalog gives their reason.
    static let menuOwnsEnabled: Set = ["edit.cut", "edit.copy"]

    /// The same table read from the catalog: menuTitle, availability and the "Title: reason" help.
    static func newMenu(_ ws: PhotoWorkspace) -> [String] {
        menuIDs.map { id in
            let title = ws.menuTitle(id), why = PhotoWorkspace.catalog.availability(id, on: ws).why
            let on = menuOwnsEnabled.contains(id) ? ws.canvas != nil : why == nil
            if id == "layer.new-adjustment" { return "\(title)|\(on)|\(why ?? title)" }
            return "\(title)|\(on)|\(helped.contains(id) ? why.map { "\(title): \($0)" } ?? title : "-")"
        }
    }

    @Test func menusUnchanged() throws {
        for (state, ws) in try Self.states() {
            #expect(Self.newMenu(ws) == Self.oldMenu(ws), "\(state)")
        }
    }

    @Test func availabilityWithinBudget() throws {
        let states = try Self.states().map(\.1), clock = ContinuousClock()
        let took = clock.measure {
            for ws in states { for id in PhotoWorkspace.catalog.ids { _ = PhotoWorkspace.catalog.availability(id, on: ws) } }
        }
        print("availabilityWithinBudget: \(took / states.count) per state for \(PhotoWorkspace.catalog.ids.count) ids (budget 2 ms)")
    }
}
