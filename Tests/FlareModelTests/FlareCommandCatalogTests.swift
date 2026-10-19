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

/// FlareWorkspace as a headless document for the laws only; save() is the document's .flare bytes.
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
    /// Two scenes; three layers on Scene 1, the middle one selected; the playhead mid-timeline; one recent file.
    static func lawsFixture() -> FlareWorkspace {
        var ws = FlareWorkspace(services: .fake())
        ws.newDocument()
        for id in ["layer-a", "layer-b", "layer-c"] {
            ws.apply(AddLayer(owner: .scene("scene-1"), layer: Layer(id: id, name: id)))
        }
        ws.apply(AddScene(scene: Scene(id: "scene-2", name: "Scene 2")))
        ws.selectLayer("layer-b")
        ws.selectTool(.rectangle)
        ws.drag(from: FlareCore.Point(x: 2, y: 2), to: FlareCore.Point(x: 30, y: 20))
        ws.drag(from: FlareCore.Point(x: 40, y: 40), to: FlareCore.Point(x: 60, y: 70))
        ws.selectTool(.select)
        ws.selectLayer("layer-b")
        ws.setCurrentFrame(5)
        ws.noteRecent("/tmp/Bounce.flare")
        return ws
    }

    /// No document, empty, one layer, a locked layer, the laws' selection, mid-drag.
    static func states() -> [(String, FlareWorkspace)] {
        var empty = FlareWorkspace(services: .fake())
        empty.newDocument()
        var one = empty
        one.apply(AddLayer(owner: .scene("scene-1"), layer: Layer(id: "layer-a", name: "Ball")))
        one.selectLayer("layer-a")
        var locked = lawsFixture()
        locked.apply(SetLayerFlags(owner: .scene("scene-1"), layerID: "layer-c", isLocked: true))
        locked.selectLayer("layer-c")
        var drag = one
        drag.selectTool(.rectangle)
        drag.dragChanged(from: FlareCore.Point(x: 2, y: 2), to: FlareCore.Point(x: 30, y: 20))
        return [("none", FlareWorkspace(services: .fake())), ("empty", empty), ("one", one), ("locked", locked),
                ("selection", lawsFixture()), ("drag", drag)]
    }

    @Test func conformance() {
        #expect(FlareWorkspace.catalog.ids.count == FlareWorkspace.coreCommands.count + FlareWorkspace.appCommands.count)
        let appIDs = Set(FlareWorkspace.appCommands.map(\.id))
        let problems = CatalogConformance.check(FlareLawsDocument.self, fixture: FlareLawsDocument(ws: Self.lawsFixture()))
        #expect(problems.filter { appIDs.contains(String($0.prefix { $0 != ":" })) } == [])
    }

    @Test func ledger() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/flare.txt")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(CommandIDLedger.check(FlareWorkspace.catalog.ids, ledger: text) == [])
        let listed = Set(text.split(separator: "\n").map(String.init))
        #expect(FlareWorkspace.catalog.ids.filter { !listed.contains($0) } == [], "every id is in the ledger")
    }

    /// Any non-empty pasteboard: the app's Paste reason with Flare data on the system pasteboard.
    static let pasteboard = Data("[]".utf8)

    /// FlareTransport.help as the app has it today, for one transport intent.
    static func transportHelp(_ intent: FlareIntent.Timeline, _ ws: FlareWorkspace) -> String? {
        guard ws.canPlay else { return "Open an animation to play it." }
        let atStart = ws.currentFrame <= 0, atEnd = ws.currentFrame >= ws.timelineFrames - 1
        let stepWraps = ws.isPlaying || (ws.loops && ws.timelineFrames > 1)
        switch intent {
        case .goToStart: return atStart ? "Already at the first frame." : nil
        case .goToEnd: return atEnd ? "Already at the last frame." : nil
        case .step(let delta) where delta < 0: return atStart && !stepWraps ? "Already at the first frame." : nil
        case .step(let delta) where delta > 0: return atEnd && !stepWraps ? "Already at the last frame." : nil
        default: return nil
        }
    }

    /// The help the app's window gives today for `id` (FlareWindow+Edit, +Tools, +Timeline, +File, +Layers).
    static func oldHelp(_ id: String, _ ws: FlareWorkspace) -> String?? {
        if let tool = FlareTool.allCases.first(where: { FlareWorkspace.toolID($0) == id }) { return ws.toolHelp(tool) }
        let noFile = ws.document == nil ? "Open or create an animation first." : nil
        switch id {
        case "file.new", "file.open": return .some(nil)
        case "file.save", "file.save-as": return noFile
        case "file.clear-recent": return ws.recent.isEmpty ? "No recent animations." : nil
        case "edit.undo": return ws.canUndo ? nil : "Nothing to undo."
        case "edit.redo": return ws.canRedo ? nil : "Nothing to redo."
        case "edit.cut": return ws.editHelp(.cut)
        case "edit.copy": return ws.editHelp(.copy)
        case "edit.paste": return ws.editHelp(.paste, pasteboard: pasteboard)
        case "edit.duplicate": return ws.editHelp(.duplicate)
        case "edit.delete": return ws.deleteHelp == nil ? nil : ws.editHelp(.delete)
        case "edit.select-all": return ws.editHelp(.selectAll)
        case "edit.deselect": return ws.editHelp(.deselect)
        case "object.bring-forward": return ws.orderHelp(forward: true)
        case "object.send-backward": return ws.orderHelp(forward: false)
        case "animate.play", "animate.loop": return ws.canPlay ? nil : "Open an animation to play it."
        case "animate.next-frame": return transportHelp(.step(1), ws)
        case "animate.previous-frame": return transportHelp(.step(-1), ws)
        case "animate.go-to-start": return transportHelp(.goToStart, ws)
        case "animate.go-to-end": return transportHelp(.goToEnd, ws)
        case "scenes.add": return ws.document == nil ? "Open an animation to add a scene to." : nil
        case "scenes.remove": return ws.selectedSceneID.map(ws.removeSceneHelp) ?? FlareLayerError.noDocument.message
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

    /// Paste's reason reads the pasteboard: with Flare data on it, an open document's Paste is available.
    @Test func pasteHelpReadsPasteboard() {
        let ws = Self.lawsFixture()
        #expect(ws.editHelp(.paste) == FakeShapes.nothingToPaste)
        #expect(FlareWorkspace.catalog.availability("edit.paste", on: ws).why == nil)
        var pasted = ws
        let copied = try? FlareWorkspace.catalog.run("edit.copy", params: .object([:]), on: &pasted).result
        let data = copied.flatMap { if case .object(let o) = $0 { o["data"] } else { nil } } ?? .null
        _ = try? FlareWorkspace.catalog.run("edit.paste", params: .object(["data": data]), on: &pasted)
        #expect(pasted.layers.count == ws.layers.count + 1)
        #expect(pasted.undoActionName == "Undo Paste")
    }

    /// The menu table today, item by item, for the items the catalog carries: FlareCommands' titles, enabled while
    /// the window's help is nil, and that help as the item's tooltip.
    static func oldMenu(_ ws: FlareWorkspace) -> [String] {
        func row(_ intent: FlareIntent, _ id: String, _ title: String? = nil) -> String {
            let help = Self.oldHelp(id, ws) ?? nil
            return "\(title ?? intent.title)|\(help == nil)|\(help ?? "")"
        }
        let samples = [("bounce", "Bounce"), ("character", "Character"), ("button", "Button"), ("keyed", "Keyed Ball")]
        let edits: [(FlareIntent.Edit, String)] = [
            (.cut, "edit.cut"), (.copy, "edit.copy"), (.paste, "edit.paste"), (.duplicate, "edit.duplicate"),
            (.delete, "edit.delete"), (.selectAll, "edit.select-all"), (.deselect, "edit.deselect"),
            (.bringForward, "object.bring-forward"), (.sendBackward, "object.send-backward"),
        ]
        return [row(.file(.new), "file.new"), row(.file(.open), "file.open"), row(.file(.clearRecent), "file.clear-recent")]
            + samples.map { "\($0.1)|\(FlareFixtures.named($0.0) != nil)|" }
            + [row(.file(.save), "file.save"), row(.file(.saveAs), "file.save-as"),
               row(.edit(.undo), "edit.undo", ws.undoActionName ?? "Undo"), row(.edit(.redo), "edit.redo", ws.redoActionName ?? "Redo")]
            + edits.map { row(.edit($0.0), $0.1) }
            + [row(.timeline(.togglePlay), "animate.play"), row(.timeline(.setLoops(true)), "animate.loop"),
               row(.timeline(.step(1)), "animate.next-frame"), row(.timeline(.step(-1)), "animate.previous-frame"),
               row(.timeline(.goToStart), "animate.go-to-start"), row(.timeline(.goToEnd), "animate.go-to-end")]
    }

    /// The same rows read from the catalog: menuTitle, availability, and the sample rule for Open Sample.
    static func newMenu(_ ws: FlareWorkspace) -> [String] {
        let ids = ["file.new", "file.open", "file.clear-recent"]
        let samples = ["bounce", "character", "button", "keyed"].map { name in
            "\(FlareWorkspace.sampleTitle(name))|\(FlareWorkspace.sampleHelp(name) == nil)|"
        }
        let rest = ["file.save", "file.save-as", "edit.undo", "edit.redo", "edit.cut", "edit.copy", "edit.paste",
                    "edit.duplicate", "edit.delete", "edit.select-all", "edit.deselect", "object.bring-forward",
                    "object.send-backward", "animate.play", "animate.loop", "animate.next-frame", "animate.previous-frame",
                    "animate.go-to-start", "animate.go-to-end"]
        func row(_ id: String) -> String {
            let why = FlareWorkspace.catalog.availability(id, on: ws).why
            return "\(ws.menuTitle(id))|\(why == nil)|\(why ?? "")"
        }
        return ids.map(row) + samples + rest.map(row)
    }

    @Test func menusUnchanged() {
        for (state, ws) in Self.states() {
            #expect(Self.newMenu(ws) == Self.oldMenu(ws), "\(state)")
        }
    }
}
