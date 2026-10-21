// FlareCommandCatalog.swift (AC-f2): Flare's menu, palette, transport and SCENES (`scenes.*`) actions as catalog commands,
// each available exactly when the window's control is. An edit's title is its undo step.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel

extension FlareWorkspace {
    public struct NoParams: Codable, Sendable {}
    public struct NameParams: Codable, Sendable { public var name: String }
    public struct DataParams: Codable, Sendable { public var data: String }
    public struct OpenParams: Codable, Sendable { public var name: String; public var data: String }
    public struct LoopParams: Codable, Sendable { public var on: Bool }
    typealias Help = @Sendable (FlareWorkspace) -> String?

    /// The FlareCore commands, then the app's; empty only if an id broke the id rule.
    public static let commands = coreCommands + appCommands
    public static let catalog = (try? CommandCatalog<FlareWorkspace>(app: "flare", commands, history: FlareCoreHistory.init)) ?? .empty(app: "flare")
    static let noFile: Help = { $0.document == nil ? "Open or create an animation first." : nil }
    static let noScene: Help = { $0.document == nil ? FlareLayerError.noDocument.message : nil }
    static let cannotPlay: Help = { $0.canPlay ? nil : "Open an animation to play it." }
    /// Any Flare data: the catalog's Paste carries its data in the params, so its reason assumes some is on hand.
    static let anyPasteboard = Data("[]".utf8)
    /// The label the menu shows for `id`: Undo and Redo name the step.
    public func menuTitle(_ id: String) -> String {
        switch id {
        case "edit.undo": undoActionName ?? "Undo"
        case "edit.redo": redoActionName ?? "Redo"
        default: Self.menuLabels[id] ?? Self.catalog.spec(id)?.title ?? id
        }
    }
    static let menuLabels = ["file.open": "Open…", "file.save-as": "Save As…", "edit.delete": "Delete", "animate.play": "Play/Pause"]
    /// `id`'s catalog spec over the reason the focused window gives for it (nil: it can run), for a menu item that
    /// holds that reason rather than the workspace; nil when the catalog lacks `id`. The item acts through its
    /// window, so a run of this spec only refuses.
    public static func menuSpec(_ id: String) -> CommandSpec<String?>? {
        guard let spec = catalog.spec(id) else { return nil }
        return .typed(spec.id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: spec.params,
                      result: spec.result, example: spec.example, availability: { $0.map(Availability.unavailable) ?? .available }) {
            (_: inout String?, _: JSONValue) throws -> JSONValue in
            throw CatalogError.unavailable(id: spec.id, why: "Run \(spec.title) from its window.")
        }
    }

    public static func sampleHelp(_ name: String) -> String? { FlareFixtures.named(name) == nil ? "No sample called \(name)." : nil }
    public static func sampleTitle(_ name: String) -> String { name == "keyed" ? "Keyed Ball" : name.capitalized }

    /// A tool's command id, in kebab case ("tool.direct-select").
    public static func toolID(_ tool: FlareTool) -> String { "tool." + tool.rawValue.map { $0.isUppercase ? "-" + $0.lowercased() : String($0) }.joined() }
    /// The transport's reason: nothing to play, or already at the end it moves to (stepping wraps while playing or looping).
    func transportHelp(back: Bool, step: Bool) -> String? {
        if let why = Self.cannotPlay(self) { return why }
        let there = back ? currentFrame <= 0 : currentFrame >= timelineFrames - 1
        let wraps = step && (isPlaying || (loops && timelineFrames > 1))
        return there && !wraps ? (back ? "Already at the first frame." : "Already at the last frame.") : nil
    }

    mutating func attempt(_ id: String, _ body: (inout FlareWorkspace) throws -> Void) throws {
        layerError = nil
        try body(&self)
        if let error = layerError { throw CatalogError.failed(id: id, message: error.message) }
    }    /// A command unavailable while `help` gives a reason, run through `attempt`.
    static func take<P: Decodable & Sendable>(_ id: String, _ title: String, _ summary: String, _ kind: CommandKind, _ params: P.Type, example: JSONValue,
                                              _ help: @escaping Help, _ run: @escaping @Sendable (inout FlareWorkspace, P) throws -> Void) -> CommandSpec<FlareWorkspace> {
        .typed(id, title: title, summary: summary, kind: kind, params: P.self, schema: P.self == NoParams.self ? ParamSchema.none : nil,
               example: example, availability: { help($0).map(Availability.unavailable) ?? .available }) { w, p in
            try w.attempt(id) { try run(&$0, p) }
            return JSONValue.object([:])
        }
    }
    static func act(_ id: String, _ title: String, _ summary: String, _ kind: CommandKind, _ help: @escaping Help,
                    _ run: @escaping @Sendable (inout FlareWorkspace) throws -> Void) -> CommandSpec<FlareWorkspace> {
        take(id, title, summary, kind, NoParams.self, example: .object([:]), help) { w, _ in try run(&w) }
    }
    static func clip(_ id: String, _ title: String, _ summary: String, _ kind: CommandKind, _ help: @escaping Help,
                     _ grab: @escaping @Sendable (inout FlareWorkspace) -> Data?) -> CommandSpec<FlareWorkspace> {
        .typed(id, title: title, summary: summary, kind: kind, params: NoParams.self, schema: ParamSchema.none, result: dataSchema,
               example: .object([:]), availability: { help($0).map(Availability.unavailable) ?? .available }) { w, _ in
            var data: Data?
            try w.attempt(id) { data = grab(&$0) }
            guard let data else { throw CatalogError.failed(id: id, message: "Nothing was copied.") }
            return JSONValue.object(["data": .string(String(decoding: data, as: UTF8.self))])
        }
    }

    static let dataSchema = ParamSchema.object(["data": .string("Flare layer data, as Copy returns it.")], required: ["data"])
    static let pasteExample: JSONValue = {
        var ws = FlareWorkspace(services: .fake())
        ws.newDocument()
        ws.apply(AddLayer(owner: .scene("scene-1"), layer: Layer(id: "layer-1", name: "Ball")), selection: .layer("layer-1"))
        return ws.copy().map { .object(["data": .string(String(decoding: $0, as: UTF8.self))]) } ?? .null
    }()
    static let openExample: JSONValue = {
        let data = (try? FlareFormat.encode(Document(scenes: [Scene(id: "scene-1", name: "Scene 1")]))) ?? Data()
        return .object(["name": .string("Ball.flare"), "data": .string(String(decoding: data, as: UTF8.self))])
    }()

    public static let appCommands: [CommandSpec<FlareWorkspace>] = [
        act("file.new", "New", "Opens a new animation with one scene.", .file, { _ in nil }) { w in w.newDocument() },
        take("file.open", "Open", "Opens a .flare file's bytes, as text.", .file, OpenParams.self, example: openExample, { _ in nil }) { w, p in
            if case .failure(let error) = decodeFile(Data(p.data.utf8)) { throw CatalogError.failed(id: "file.open", message: error.message) }
            try? w.open(Data(p.data.utf8), named: p.name)
        },
        take("file.open-sample", "Open Sample", "Opens a sample: bounce, character, button or keyed.", .file, NameParams.self,
            example: .object(["name": .string("bounce")]), { _ in nil }) { w, p in
            guard let doc = FlareFixtures.named(p.name) else { throw CatalogError.failed(id: "file.open-sample", message: sampleHelp(p.name) ?? "") }
            w.finishOpen(.success(doc), named: sampleTitle(p.name))
        },
        act("file.save", "Save", "Marks the animation saved under its file name.", .file, noFile) { w in if let save = w.saveData() { w.didSave(save, named: w.title + ".flare") } },
        take("file.save-as", "Save As", "Marks the animation saved under a new file name.", .file, NameParams.self,
            example: .object(["name": .string("Copy.flare")]), noFile) { w, p in if let save = w.saveData() { w.didSave(save, named: p.name) } },
        act("file.clear-recent", "Clear Menu", "Empties the Open Recent list.", .view,
            { $0.recent.isEmpty ? "No recent animations." : nil }) { w in w.clearRecent() },
        act("edit.undo", "Undo", "Undoes the last edit.", .view, { $0.canUndo ? nil : "Nothing to undo." }) { w in w.undo() },
        act("edit.redo", "Redo", "Redoes the last undone edit.", .view, { $0.canRedo ? nil : "Nothing to redo." }) { w in w.redo() },
        clip("edit.cut", "Cut", "Copies the selected layers, then removes them.", .edit, { $0.editHelp(.cut) }) { $0.cut() },
        clip("edit.copy", "Copy", "Copies the selected layers as Flare data.", .query, { $0.editHelp(.copy) }) { $0.copy() },
        take("edit.paste", "Paste", "Pastes Flare data above the selected layer and selects it.", .edit, DataParams.self,
            example: pasteExample, { $0.editHelp(.paste, pasteboard: anyPasteboard) }) { w, p in w.paste(Data(p.data.utf8)) },
        act("edit.duplicate", "Duplicate", "Duplicates the selected layers.", .edit, { $0.editHelp(.duplicate) }) { w in w.duplicate() },
        act("edit.delete", "Delete", "Deletes the selected keyframes, else the selected items or layers.", .edit,
            { $0.deleteHelp == nil ? nil : $0.editHelp(.delete) }) { w in w.deleteHelp == nil ? w.deleteSelection() : w.delete() },
        act("edit.select-all", "Select All", "Selects every item on the stage.", .view, { $0.editHelp(.selectAll) }) { w in w.selectAll() },
        act("timeline.select-all-keys", "Select All Keys", "Picks every key on every layer of the edited scene or symbol, hidden ones too.", .view,
            { $0.selectAllKeysHelp }) { w in w.selectAllKeys() },
        act("edit.deselect", "Deselect", "Clears the stage and layer selection.", .view, { $0.editHelp(.deselect) }) { w in w.deselect() },
        act("object.bring-forward", "Bring Forward", "Moves the selected layer one place up.", .edit, { $0.orderHelp(forward: true) }) { w in w.bringForward() },
        act("object.send-backward", "Send Backward", "Moves the selected layer one place down.", .edit, { $0.orderHelp(forward: false) }) { w in w.sendBackward() },
    ] + FlareTool.allCases.filter { $0 != .shape }.map { tool in  // tool.shape comes from ShapeCommands (shape-tools FS-6)
        act(toolID(tool), FlareIntent.tools(.choose(tool)).title, "Picks the \(tool.rawValue) tool for stage drags.", .view,
            { $0.toolHelp(tool) }) { w in w.selectTool(tool) }
    } + [
        act("animate.play", "Play", "Plays or pauses the timeline.", .view, cannotPlay) { w in w.togglePlay() },
        take("animate.loop", "Loop", "Turns looping playback on or off.", .view, LoopParams.self,
            example: .object(["on": .bool(true)]), cannotPlay) { w, p in w.setLoops(p.on) },
        act("animate.next-frame", "Next Frame", "Steps one frame on.", .view, { $0.transportHelp(back: false, step: true) }) { w in w.stepFrame(by: 1) },
        act("animate.previous-frame", "Previous Frame", "Steps one frame back.", .view, { $0.transportHelp(back: true, step: true) }) { w in w.stepFrame(by: -1) },
        act("animate.go-to-start", "Go to Start", "Moves the playhead to the first frame.", .view, { $0.transportHelp(back: true, step: false) }) { w in w.goToStart() },
        act("animate.go-to-end", "Go to End", "Moves the playhead to the last frame.", .view, { $0.transportHelp(back: false, step: false) }) { w in w.goToEnd() },
        act("scenes.add", "Add Scene", "Adds a scene like the selected one and selects it.", .edit, { $0.document == nil ? "Open an animation to add a scene to." : nil }) { w in w.addScene() },
        take("scenes.rename", "Rename Scene", "Renames the selected scene.", .edit, NameParams.self,
            example: .object(["name": .string("Intro")]), noScene) { w, p in w.renameScene(w.selectedSceneID ?? "", to: p.name) },
        act("scenes.remove", "Delete Scene", "Removes the selected scene; its undo step is Delete Scene.", .edit,
            { w in w.selectedSceneID.map(w.removeSceneHelp) ?? FlareLayerError.noDocument.message }) { w in w.removeScene(w.selectedSceneID ?? "") },
        setFrameRate,  // frame-rates FR-10, FlareFrameRate+Kernel.swift
    ]
}
