// FlareCommandCatalog.swift (adopt-command-catalog AC-f2): Flare's menu, palette, transport and SCENES actions as
// catalog commands over FlareWorkspace, beside AC-f1's FlareCore commands; ids `<menu>.<action>`, the SCENES sidebar's
// `scenes.*` (FlareCore holds `scene.*`). Availability is the help the window gives today (FlareWindow+Edit, +Tools,
// +Timeline, +File, +Layers), with Paste's read as if Flare data is on the pasteboard, since the data is the params.
// Copy and Cut return that data as text. An edit's title is its undo step, `menuTitle(_:)` the menu's label. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel

extension FlareWorkspace {
    public struct NoParams: Codable, Sendable {}
    /// A file's name; Flare data as text (pasteboard or .flare file); a scene id; Loop on or off.
    public struct NameParams: Codable, Sendable { public var name: String }
    public struct DataParams: Codable, Sendable { public var data: String }
    public struct OpenParams: Codable, Sendable { public var name: String; public var data: String }
    public struct SceneParams: Codable, Sendable { public var id: String }
    public struct LoopParams: Codable, Sendable { public var on: Bool }

    /// The FlareCore commands, then the app's; empty only if an id broke the id rule.
    public static let commands = coreCommands + appCommands
    public static let catalog = (try? CommandCatalog<FlareWorkspace>(app: "flare", commands, history: FlareCoreHistory.init))
        ?? .empty(app: "flare")

    static let noFile = "Open or create an animation first.", cannotPlay = "Open an animation to play it."
    static let first = "Already at the first frame.", last = "Already at the last frame."
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
    static let menuLabels = ["file.open": "Open…", "file.save-as": "Save As…", "file.clear-recent": "Clear Menu",
                             "edit.delete": "Delete", "animate.play": "Play/Pause"]

    /// Open Sample's reason for `name`, and its menu title.
    public static func sampleHelp(_ name: String) -> String? { FlareFixtures.named(name) == nil ? "No sample called \(name)." : nil }
    public static func sampleTitle(_ name: String) -> String { name == "keyed" ? "Keyed Ball" : name.capitalized }

    /// The transport's reason: nothing to play, or already at the end it moves to (stepping wraps while playing or looping).
    func transportHelp(back: Bool, step: Bool) -> String? {
        guard canPlay else { return Self.cannotPlay }
        let there = back ? currentFrame <= 0 : currentFrame >= timelineFrames - 1
        let wraps = step && (isPlaying || (loops && timelineFrames > 1))
        return there && !wraps ? (back ? Self.first : Self.last) : nil
    }

    static func gate(_ help: @escaping @Sendable (FlareWorkspace) -> String?) -> @Sendable (FlareWorkspace) -> Availability {
        { help($0).map(Availability.unavailable) ?? .available }
    }
    /// Runs `body`; a refusal it leaves in `layerError` throws.
    mutating func attempt(_ id: String, _ body: (inout FlareWorkspace) throws -> Void) throws {
        layerError = nil
        try body(&self)
        if let error = layerError { throw CatalogError.failed(id: id, message: error.message) }
    }
    static func act(_ id: String, _ title: String, _ summary: String, _ kind: CommandKind,
                    _ help: @escaping @Sendable (FlareWorkspace) -> String?,
                    _ run: @escaping @Sendable (inout FlareWorkspace) throws -> Void) -> CommandSpec<FlareWorkspace> {
        .typed(id, title: title, summary: summary, kind: kind, params: NoParams.self, schema: ParamSchema.none,
               example: .object([:]), availability: gate(help)) { w, _ in try w.attempt(id, run); return JSONValue.object([:]) }
    }
    static func text(_ data: Data?, _ id: String) throws -> JSONValue {
        guard let data else { throw CatalogError.failed(id: id, message: "Nothing was copied.") }
        return .object(["data": .string(String(decoding: data, as: UTF8.self))])
    }

    static let dataSchema = ParamSchema.object(["data": .string("Flare layer data, as Copy returns it.")], required: ["data"])
    static let nameSchema = ParamSchema.object(["name": .string("The name.", maxLength: 255)], required: ["name"])
    static let pasteExample: JSONValue = {
        var ws = FlareWorkspace(services: .fake())
        ws.newDocument()
        ws.apply(AddLayer(owner: .scene("scene-1"), layer: Layer(id: "layer-1", name: "Ball")), selection: .layer("layer-1"))
        return (try? text(ws.copy(), "edit.copy")) ?? .null
    }()
    static let openExample: JSONValue = {
        let data = (try? FlareFormat.encode(Document(scenes: [Scene(id: "scene-1", name: "Scene 1")]))) ?? Data()
        return .object(["name": .string("Ball.flare"), "data": .string(String(decoding: data, as: UTF8.self))])
    }()

    /// One command per menu item, palette tool, transport button and SCENES action the app has today.
    public static let appCommands: [CommandSpec<FlareWorkspace>] = fileCommands + editCommands + FlareTool.allCases.map { tool in
        act(toolID(tool), FlareIntent.tools(.choose(tool)).title, "Picks the \(tool.rawValue) tool for stage drags.",
            .view, { $0.toolHelp(tool) }) { $0.selectTool(tool) }
    } + animateCommands + sceneCommands

    /// A tool's command id: "tool." and its name in kebab case ("tool.direct-select").
    public static func toolID(_ tool: FlareTool) -> String {
        "tool." + tool.rawValue.map { $0.isUppercase ? "-" + $0.lowercased() : String($0) }.joined()
    }

    static let fileCommands: [CommandSpec<FlareWorkspace>] = [
        act("file.new", "New", "Opens a new animation with one scene.", .file, { _ in nil }) { $0.newDocument() },
        .typed("file.open", title: "Open", summary: "Opens a .flare file's bytes, as text.", kind: .file, params: OpenParams.self,
               schema: .object(["name": .string(maxLength: 255), "data": .string()], required: ["name", "data"]),
               example: openExample) { w, p in
            if case .failure(let error) = decodeFile(Data(p.data.utf8)) { throw CatalogError.failed(id: "file.open", message: error.message) }
            try? w.open(Data(p.data.utf8), named: p.name)
            return JSONValue.object([:])
        },
        .typed("file.open-sample", title: "Open Sample", summary: "Opens a sample: bounce, character, button or keyed.", kind: .file,
               params: NameParams.self, schema: nameSchema, example: .object(["name": .string("bounce")])) { w, p in
            if let why = sampleHelp(p.name) { throw CatalogError.unavailable(id: "file.open-sample", why: why) }
            if let doc = FlareFixtures.named(p.name) { w.finishOpen(.success(doc), named: sampleTitle(p.name)) }
            return JSONValue.object([:])
        },
        act("file.save", "Save", "Marks the animation saved under its file name.", .file, { $0.document == nil ? noFile : nil }) { w in
            if let save = w.saveData() { w.didSave(save, named: w.title + ".flare") }
        },
        .typed("file.save-as", title: "Save As", summary: "Marks the animation saved under a new file name.", kind: .file,
               params: NameParams.self, schema: nameSchema, example: .object(["name": .string("Copy.flare")]),
               availability: gate { $0.document == nil ? noFile : nil }) { w, p in
            if let save = w.saveData() { w.didSave(save, named: p.name) }
            return JSONValue.object([:])
        },
        act("file.clear-recent", "Clear Menu", "Empties the Open Recent list.", .view,
            { $0.recent.isEmpty ? "No recent animations." : nil }) { $0.clearRecent() },
    ]

    static let editCommands: [CommandSpec<FlareWorkspace>] = [
        act("edit.undo", "Undo", "Undoes the last edit.", .view, { $0.canUndo ? nil : "Nothing to undo." }) { $0.undo() },
        act("edit.redo", "Redo", "Redoes the last undone edit.", .view, { $0.canRedo ? nil : "Nothing to redo." }) { $0.redo() },
        .typed("edit.cut", title: "Cut", summary: "Copies the selected layers, then removes them.", kind: .edit, params: NoParams.self,
               schema: ParamSchema.none, result: dataSchema, example: .object([:]), availability: gate { $0.editHelp(.cut) }) { w, _ in
            var data: Data?
            try w.attempt("edit.cut") { data = $0.cut() }
            return try text(data, "edit.cut")
        },
        .typed("edit.copy", title: "Copy", summary: "Copies the selected layers as Flare data.", kind: .query, params: NoParams.self,
               schema: ParamSchema.none, result: dataSchema, example: .object([:]), availability: gate { $0.editHelp(.copy) }) { w, _ in
            var data: Data?
            try w.attempt("edit.copy") { data = $0.copy() }
            return try text(data, "edit.copy")
        },
        .typed("edit.paste", title: "Paste", summary: "Pastes Flare data above the selected layer and selects it.", kind: .edit,
               params: DataParams.self, schema: dataSchema, example: pasteExample,
               availability: gate { $0.editHelp(.paste, pasteboard: anyPasteboard) }) { w, p in
            try w.attempt("edit.paste") { $0.paste(Data(p.data.utf8)) }
            return JSONValue.object([:])
        },
        act("edit.duplicate", "Duplicate", "Duplicates the selected layers.", .edit, { $0.editHelp(.duplicate) }) { $0.duplicate() },
        act("edit.delete", "Delete", "Deletes the selected keyframes, else the selected items or layers.", .edit,
            { $0.deleteHelp == nil ? nil : $0.editHelp(.delete) }) { w in
            if w.deleteHelp == nil { w.deleteSelection() } else { w.delete() }
        },
        act("edit.select-all", "Select All", "Selects every item on the stage.", .view, { $0.editHelp(.selectAll) }) { $0.selectAll() },
        act("edit.deselect", "Deselect", "Clears the stage and layer selection.", .view, { $0.editHelp(.deselect) }) { $0.deselect() },
        act("object.bring-forward", "Bring Forward", "Moves the selected layer one place up.", .edit,
            { $0.orderHelp(forward: true) }) { $0.bringForward() },
        act("object.send-backward", "Send Backward", "Moves the selected layer one place down.", .edit,
            { $0.orderHelp(forward: false) }) { $0.sendBackward() },
    ]

    static let animateCommands: [CommandSpec<FlareWorkspace>] = [
        act("animate.play", "Play", "Plays or pauses the timeline.", .view, { $0.canPlay ? nil : cannotPlay }) { $0.togglePlay() },
        .typed("animate.loop", title: "Loop", summary: "Turns looping playback on or off.", kind: .view, params: LoopParams.self,
               schema: .object(["on": .boolean], required: ["on"]), example: .object(["on": .bool(true)]),
               availability: gate { $0.canPlay ? nil : cannotPlay }) { w, p in w.setLoops(p.on); return JSONValue.object([:]) },
        act("animate.next-frame", "Next Frame", "Steps one frame on.", .view,
            { $0.transportHelp(back: false, step: true) }) { $0.stepFrame(by: 1) },
        act("animate.previous-frame", "Previous Frame", "Steps one frame back.", .view,
            { $0.transportHelp(back: true, step: true) }) { $0.stepFrame(by: -1) },
        act("animate.go-to-start", "Go to Start", "Moves the playhead to the first frame.", .view,
            { $0.transportHelp(back: true, step: false) }) { $0.goToStart() },
        act("animate.go-to-end", "Go to End", "Moves the playhead to the last frame.", .view,
            { $0.transportHelp(back: false, step: false) }) { $0.goToEnd() },
    ]

    static let sceneCommands: [CommandSpec<FlareWorkspace>] = [
        act("scenes.add", "Add Scene", "Adds a scene like the selected one and selects it.", .edit,
            { $0.document == nil ? "Open an animation to add a scene to." : nil }) { $0.addScene() },
        .typed("scenes.rename", title: "Rename Scene", summary: "Renames the selected scene.", kind: .edit, params: NameParams.self,
               schema: nameSchema, example: .object(["name": .string("Intro")]),
               availability: gate { $0.selectedScene == nil ? FlareLayerError.noDocument.message : nil }) { w, p in
            let id = w.selectedSceneID ?? ""
            try w.attempt("scenes.rename") { $0.renameScene(id, to: p.name) }
            return JSONValue.object([:])
        },
        act("scenes.remove", "Delete Scene", "Removes the selected scene; its undo step is Delete Scene.", .edit,
            { w in w.selectedSceneID.map(w.removeSceneHelp) ?? FlareLayerError.noDocument.message }) { w in
            if let id = w.selectedSceneID { w.removeScene(id) }
        },
        .typed("scenes.select", title: "Select Scene", summary: "Selects a scene by id.", kind: .view, params: SceneParams.self,
               schema: .object(["id": .string()], required: ["id"]), example: .object(["id": .string("scene-2")]),
               availability: gate { $0.document == nil ? FlareLayerError.noDocument.message : nil }) { w, p in
            guard w.scenes.contains(where: { $0.id == p.id }) else {
                throw CatalogError.failed(id: "scenes.select", message: "There is no scene \(p.id).")
            }
            w.selectScene(p.id)
            return JSONValue.object([:])
        },
    ]
}
