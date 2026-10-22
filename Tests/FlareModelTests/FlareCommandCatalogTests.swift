// FlareCommandCatalogTests.swift (AC-f2): Flare's catalog keeps the laws, its ledger, today's help and today's menus.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel
import Testing
@testable import FlareModel

struct FlareLawsDocument: HeadlessDocument {
    var ws: FlareWorkspace
    static let app = "flare", openExtensions: [String] = [], exportFormats: [String] = []
    static let catalog = (try? CommandCatalog<FlareLawsDocument>(app: app, FlareWorkspace.commands.map(lift),
                                                                 history: { FlareCoreHistory($0.ws) })) ?? .empty(app: app)
    static func lift(_ spec: CommandSpec<FlareWorkspace>) -> CommandSpec<FlareLawsDocument> {
        .typed(spec.id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: spec.params,
               result: spec.result, example: spec.example, availability: { spec.availability($0.ws) }) { doc, params in
            try FlareWorkspace.catalog.run(spec.id, params: params, on: &doc.ws).result
        }
    }
    static func open(_ data: Data, name: String) throws -> FlareLawsDocument { throw CatalogError.failed(id: "open", message: "laws only") }
    static func new(_ options: JSONValue) throws -> FlareLawsDocument { FlareLawsDocument(ws: FlareWorkspace(services: .fake())) }
    func save() throws -> Data { try ws.document.map(FlareFormat.encode) ?? Data() }
    func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { [] }
    func summary() -> JSONValue { .null }
}

struct FlareCommandCatalogTests {
    static func lawsFixture() -> FlareWorkspace {
        var ws = FlareWorkspace(services: .fake())
        ws.newDocument()
        for id in ["layer-a", "layer-b", "layer-c"] { ws.apply(AddLayer(owner: .scene("scene-1"), layer: Layer(id: id, name: id))) }
        ws.apply(AddScene(scene: Scene(id: "scene-2", name: "Scene 2")))
        // A key, so Select All Keys (key-select-all KS-1) has one to pick.
        ws.apply(SetKeyframe(owner: .scene("scene-1"), layerID: "layer-c", property: "x", keyframe: Keyframe(frame: 0, value: 0)))
        ws.selectLayer("layer-b")
        ws.selectTool(.rectangle)
        ws.drag(from: FlareCore.Point(x: 2, y: 2), to: FlareCore.Point(x: 30, y: 20))
        ws.selectTool(.select)
        ws.selectLayer("layer-b")
        ws.setCurrentFrame(5)
        ws.noteRecent("/tmp/Bounce.flare")
        return ws
    }

    /// No document, empty, one layer, a locked layer, the laws' fixture, mid-drag.
    static func states() -> [(String, FlareWorkspace)] {
        var empty = FlareWorkspace(services: .fake()), one: FlareWorkspace, locked = lawsFixture()
        empty.newDocument()
        one = empty
        one.apply(AddLayer(owner: .scene("scene-1"), layer: Layer(id: "layer-a", name: "Ball")))
        one.selectLayer("layer-a")
        locked.apply(SetLayerFlags(owner: .scene("scene-1"), layerID: "layer-c", isLocked: true))
        locked.selectLayer("layer-c")
        var drag = one
        drag.selectTool(.rectangle)
        drag.dragChanged(from: FlareCore.Point(x: 2, y: 2), to: FlareCore.Point(x: 30, y: 20))
        return [("none", FlareWorkspace(services: .fake())), ("empty", empty), ("one", one), ("locked", locked),
                ("fixture", lawsFixture()), ("drag", drag)]
    }

    @Test func conformance() {
        #expect(FlareWorkspace.catalog.ids.count == FlareWorkspace.coreCommands.count + FlareWorkspace.appCommands.count)
        let appIDs = Set(FlareWorkspace.appCommands.map(\.id))
        var ws = Self.lawsFixture()
        // The drawn rectangle with a three-stop linear fill, so every fill.* example can run (gradient-fill FG-5).
        ws.selectLayer("rectangle-1")
        ws.runFill(.type(.linear))
        ws.runFill(.add(offset: 0.5))
        let problems = CatalogConformance.check(FlareLawsDocument.self, fixture: FlareLawsDocument(ws: ws))
        #expect(problems.filter { appIDs.contains(String($0.prefix { $0 != ":" })) } == [])
    }
    @Test func ledger() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/flare.txt")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(CommandIDLedger.check(FlareWorkspace.catalog.ids, ledger: text) == [])
        #expect(Set(FlareWorkspace.catalog.ids).isSubset(of: text.split(separator: "\n").map(String.init)), "every id is listed")
    }
    /// FlareTransport.help as the app has it today.
    static func transportHelp(_ intent: FlareIntent.Timeline, _ ws: FlareWorkspace) -> String? {
        guard ws.canPlay else { return "Open an animation to play it." }
        let atStart = ws.currentFrame <= 0, atEnd = ws.currentFrame >= ws.timelineFrames - 1
        let wraps = ws.isPlaying || (ws.loops && ws.timelineFrames > 1)
        switch intent {
        case .goToStart, .step(-1): return atStart && (intent == .goToStart || !wraps) ? "Already at the first frame." : nil
        case .goToEnd, .step(1): return atEnd && (intent == .goToEnd || !wraps) ? "Already at the last frame." : nil
        default: return nil
        }
    }

    /// The help the window gives today for `id` (FlareWindow+Edit, +Tools, +Timeline, +File, +Layers); .none without a control.
    static func oldHelp(_ id: String, _ ws: FlareWorkspace) -> String?? {
        if let tool = FlareTool.allCases.first(where: { FlareWorkspace.toolID($0) == id }) { return ws.toolHelp(tool) }
        let edits: [String: FlareEditAction] = ["edit.cut": .cut, "edit.copy": .copy, "edit.duplicate": .duplicate,
                                                 "edit.select-all": .selectAll, "edit.deselect": .deselect]
        if let edit = edits[id] { return ws.editHelp(edit) }
        switch id {
        case "file.new", "file.open": return .some(nil)
        case "file.save", "file.save-as": return .some(ws.document == nil ? "Open or create an animation first." : nil)
        case "file.clear-recent": return .some(ws.recent.isEmpty ? "No recent animations." : nil)
        case "edit.undo": return .some(ws.canUndo ? nil : "Nothing to undo.")
        case "edit.redo": return .some(ws.canRedo ? nil : "Nothing to redo.")
        case "edit.paste": return ws.editHelp(.paste, pasteboard: Data("[]".utf8))
        case "edit.delete": return .some(ws.deleteHelp == nil ? nil : ws.editHelp(.delete))
        case "object.bring-forward", "object.send-backward": return ws.orderHelp(forward: id == "object.bring-forward")
        case "animate.play", "animate.loop": return .some(ws.canPlay ? nil : "Open an animation to play it.")
        case "animate.next-frame": return transportHelp(.step(1), ws)
        case "animate.previous-frame": return transportHelp(.step(-1), ws)
        case "animate.go-to-start": return transportHelp(.goToStart, ws)
        case "animate.go-to-end": return transportHelp(.goToEnd, ws)
        case "scenes.add": return .some(ws.document == nil ? "Open an animation to add a scene to." : nil)
        case "scenes.remove": return .some(ws.selectedSceneID.map(ws.removeSceneHelp) ?? FlareLayerError.noDocument.message)
        default: return .none
        }
    }

    @Test func availabilityMatchesHelp() {
        var checked = 0
        for (state, ws) in Self.states() {
            for id in FlareWorkspace.catalog.ids {
                guard case .some(let old) = Self.oldHelp(id, ws) else { continue }
                checked += 1
                #expect(FlareWorkspace.catalog.availability(id, on: ws).why == old, "\(id) in \(state)")
            }
        }
        #expect(checked >= 6 * 25)
    }

    @Test func pasteHelpReadsPasteboard() throws {
        var ws = Self.lawsFixture()
        #expect(ws.editHelp(.paste) == FakeShapes.nothingToPaste)
        #expect(FlareWorkspace.catalog.availability("edit.paste", on: ws).why == nil)
        let layers = ws.layers.count
        let copied = try FlareWorkspace.catalog.run("edit.copy", params: .object([:]), on: &ws).result
        _ = try FlareWorkspace.catalog.run("edit.paste", params: copied, on: &ws)
        #expect(ws.layers.count == layers + 1 && ws.undoActionName == "Undo Paste")
    }

    /// The catalog's menu items in FlareCommands' order, with the intent that titles each today.
    static let menu: [(String, FlareIntent)] = [
        ("file.new", .file(.new)), ("file.open", .file(.open)), ("file.clear-recent", .file(.clearRecent)), ("file.save", .file(.save)), ("file.save-as", .file(.saveAs)),
        ("edit.cut", .edit(.cut)), ("edit.copy", .edit(.copy)), ("edit.paste", .edit(.paste)), ("edit.duplicate", .edit(.duplicate)), ("edit.delete", .edit(.delete)),
        ("edit.select-all", .edit(.selectAll)), ("edit.deselect", .edit(.deselect)), ("object.bring-forward", .edit(.bringForward)), ("object.send-backward", .edit(.sendBackward)),
        ("animate.play", .timeline(.togglePlay)), ("animate.loop", .timeline(.setLoops(true))), ("animate.next-frame", .timeline(.step(1))),
        ("animate.previous-frame", .timeline(.step(-1))), ("animate.go-to-start", .timeline(.goToStart)), ("animate.go-to-end", .timeline(.goToEnd)),
    ]
    static let samples = ["bounce": "Bounce", "character": "Character", "button": "Button", "keyed": "Keyed Ball"].sorted { $0.key < $1.key }

    /// Today's menu rows ("title|tooltip", disabled exactly when the tooltip is set) against the catalog's.
    @Test func menusUnchanged() {
        for (state, ws) in Self.states() {
            let titled = Self.menu.map { ($0.0, $0.1.title) }
                + [("edit.undo", ws.undoActionName ?? "Undo"), ("edit.redo", ws.redoActionName ?? "Redo")]
            let old = titled.map { "\($0.1)|\(Self.oldHelp($0.0, ws).flatMap { $0 } ?? "")" }
                + Self.samples.map { "\($0.value)|\(FlareFixtures.named($0.key) == nil)" }
            let new = (Self.menu.map(\.0) + ["edit.undo", "edit.redo"]).map {
                "\(ws.menuTitle($0))|\(FlareWorkspace.catalog.availability($0, on: ws).why ?? "")"
            } + Self.samples.map { "\(FlareWorkspace.sampleTitle($0.key))|\(FlareWorkspace.sampleHelp($0.key) != nil)" }
            #expect(new == old, "\(state)")
        }
    }

    /// The ⌘A menu item's spec (key-select-all KS-a): the catalog's title and summary, off with the window's reason.
    @Test func menuSpecTakesTheWindowsReason() throws {
        let spec = try #require(FlareWorkspace.menuSpec("timeline.select-all-keys"))
        #expect(spec.title == "Select All Keys" && spec.summary == FlareWorkspace.catalog.spec("timeline.select-all-keys")?.summary)
        #expect(spec.availability(nil) == .available)
        #expect(spec.availability(FlareWorkspace.noKeysToSelect) == .unavailable(FlareWorkspace.noKeysToSelect))
        #expect(FlareWorkspace.menuSpec("timeline.no-such") == nil)
    }
}
