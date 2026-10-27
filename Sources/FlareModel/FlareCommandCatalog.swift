// FlareCommandCatalog.swift (AC-f2): Flare's menu, palette, transport, SCENES (`scenes.*`) and fill (`fill.*`) actions as catalog commands,
// each available exactly when the window's control is. An edit's title is its undo step. Command-state CS-11 adds the
// bare controls' commands: the New sheet's values on `file.new`, frame labels, the timeline's key and frame edits and the
// recovery offer's Restore and Discard (off while the open animation has unsaved changes).
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
    public struct LabelParams: Codable, Sendable { public var name: String? }
    public struct CountParams: Codable, Sendable { public var count: Int? }
    /// The New Animation sheet's values; none at all is File > New's default animation.
    public struct NewParams: Codable, Sendable {
        public var preset: String?, width: Double?, height: Double?, fps: Int?, durationFrames: Int?, background: String?
    }
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
    static let exampleFile: JSONValue = {
        let data = (try? FlareFormat.encode(Document(scenes: [Scene(id: "scene-1", name: "Scene 1")]))) ?? Data()
        return .string(String(decoding: data, as: UTF8.self))
    }()
    static let openExample: JSONValue = .object(["name": .string("Ball.flare"), "data": exampleFile])

    public static let appCommands: [CommandSpec<FlareWorkspace>] = [
        .typed("file.new", title: "New", summary: "Opens a new animation with one scene, from the New Animation sheet's values when given.",
               kind: .file, params: NewParams.self, schema: newSchema, example: .object(["preset": .string("Square")]),
               availability: { _ in .available }) { w, p in try w.attemptNew(p) },
        take("file.open", "Open", "Opens a .flare file's bytes, or a Lottie .json's as an untitled animation, as text.", .file,
             OpenParams.self, example: openExample, { _ in nil }) { w, p in
            if p.name.lowercased().hasSuffix(".json") {
                do throws(FlareOpenError) { _ = try w.openLottie(Data(p.data.utf8), named: p.name) } catch { throw CatalogError.failed(id: "file.open", message: error.message) }
                return
            }
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
        take("frame.label", "Set Frame Label", "Names the label at the playhead; no name removes it.", .edit, LabelParams.self,
            example: .object(["name": .string("Intro")]), { $0.timelineHelp("Open an animation to label its frames.") }) { w, p in try w.label(p.name) },
        take("timeline.delete-keys", "Delete Keyframe", "Deletes the selected keyframes as one step.", .edit, NoParams.self, example: .object([:]),
            { $0.timelineHelp() ?? ($0.selectedKeys.isEmpty ? selectKeyFirst : nil) }) { w, _ in try w.timelineEdit("timeline.delete-keys") { $0.removeSelectedKeys() } },
        take("timeline.insert-frames", "Insert Frame", "Inserts frames (count, default 1) at the playhead on every layer.", .edit, CountParams.self,
            example: .object(["count": .number(1)]), { $0.timelineHelp() }) { w, p in try w.timelineEdit("timeline.insert-frames") { $0.insertFrames(p.count ?? 1) } },
        take("timeline.remove-frames", "Remove Frame", "Removes frames (count, default 1) at the playhead on every layer.", .edit, CountParams.self,
            example: .object(["count": .number(1)]), { $0.timelineHelp() }) { w, p in try w.timelineEdit("timeline.remove-frames") { $0.removeFrames(p.count ?? 1) } },
        take("recovery.restore", "Restore", "Opens a recovered animation's bytes, as text, as unsaved work.", .file, DataParams.self,
            example: .object(["data": exampleFile]), { $0.recoveryHelp }) { w, p in try w.restore(Data(p.data.utf8)) },
        act("recovery.discard", "Discard", "Turns down the recovery offer; the window removes the recovery file.", .file, { $0.recoveryHelp }) { _ in },
        act("scenes.add", "Add Scene", "Adds a scene like the selected one and selects it.", .edit, { $0.document == nil ? "Open an animation to add a scene to." : nil }) { w in w.addScene() },
        take("scenes.rename", "Rename Scene", "Renames the selected scene.", .edit, NameParams.self,
            example: .object(["name": .string("Intro")]), noScene) { w, p in w.renameScene(w.selectedSceneID ?? "", to: p.name) },
        act("scenes.remove", "Delete Scene", "Removes the selected scene; its undo step is Delete Scene.", .edit,
            { w in w.selectedSceneID.map(w.removeSceneHelp) ?? FlareLayerError.noDocument.message }) { w in w.removeScene(w.selectedSceneID ?? "") },
        setFrameRate,  // frame-rates FR-10, FlareFrameRate+Kernel.swift
    ] + GradientCommands.specs(FlareWorkspace.self)  // the eight fill.* commands (gradient-fill FG-5)
        + FileFlowCommands.specs(FlareWorkspace.self)  // file.recent, open-recent, clear-recent, open-in, drop (file-flow FL-3)
        + hiddenCommands  // the beta.2 items the menus hide (no-placeholders NP-3)
        + PathCommands.specs(FlareWorkspace.self)  // the twelve path.* commands, the Pen and Direct Select's points (pen-paths FP-6)
        + [importReportCommand]  // the last Lottie open's skipped parts (lottie-open LO-5, FlareLottieNote.swift)
        + documentSetupCommands  // document.read-settings, document.set-settings (document-setup DS-14)
}

extension FlareWorkspace {
    /// The beta.2 commands (no-placeholders NP-3): id, title, and the name `laterReason` gives.
    static let betaTwo: [(id: String, title: String, name: String)] = [
        ("view.toggle-onion", "Onion Skin", "Onion skin"), ("view.toggle-motion-path", "Motion Path", "Motion path"),
        ("window.interactions", "Interactions", "Interactions"), ("window.assist", "Animate with Assist", "Assist"),
        ("library.convert-to-symbol", "Convert to Symbol", "Convert to Symbol"), ("library.exit-symbol", "Exit Symbol", "Exit Symbol"),
    ]
    /// Commands whose menu items the beta hides; each stays in the catalog, unavailable with `laterReason`.
    public static let menuHidden = Set(betaTwo.map(\.id))
    /// Why a hidden command can't run: "Onion skin comes in a later beta."
    public static func laterReason(_ id: String) -> String {
        "\(betaTwo.first { $0.id == id }?.name ?? "This") comes in a later beta."
    }
    static let hiddenCommands = betaTwo.map { command in
        act(command.id, command.title, "Comes in a later beta; the menu hides it.", .view, { _ in laterReason(command.id) }) { _ in }
    }

    /// Why Restore and Discard wait: the recovery file holds the open animation's unsaved changes.
    public static let recoveryKeepsEdits = "The open animation has unsaved changes; save them first."
    var recoveryHelp: String? { isDirty ? Self.recoveryKeepsEdits : nil }
    /// The timeline's reason with no animation open (FlareWindow.timelineHelp).
    func timelineHelp(_ why: String = "Open an animation to edit its timeline.") -> String? { document == nil ? why : nil }

    static let newSchema = ParamSchema.object([
        "preset": .string("A canvas preset's name.", oneOf: CanvasPreset.all.map(\.name)),
        "width": .number("Canvas width in points.", minimum: 1, maximum: NewDocumentSpec.maxSide),
        "height": .number("Canvas height in points.", minimum: 1, maximum: NewDocumentSpec.maxSide),
        "fps": .integer("Frame rate.", minimum: NewDocumentSpec.fpsRange.lowerBound, maximum: NewDocumentSpec.fpsRange.upperBound),
        "durationFrames": .integer("Length in frames.", minimum: NewDocumentSpec.durationRange.lowerBound, maximum: NewDocumentSpec.durationRange.upperBound),
        "background": .string("Background color, \"#RRGGBB\"."),
    ], required: [])

    /// File > New with no values; the sheet's Create with its values, refused with the sheet's problem.
    mutating func attemptNew(_ p: NewParams) throws -> JSONValue {
        guard p.preset != nil || p.width != nil || p.height != nil || p.fps != nil || p.durationFrames != nil || p.background != nil else {
            newDocument()
            return .object([:])
        }
        let named = CanvasPreset.all.first { $0.name == p.preset }
        var spec = NewDocumentSpec(preset: named ?? .hd1080)
        spec.preset = named
        spec.width = p.width ?? spec.width
        spec.height = p.height ?? spec.height
        spec.fps = p.fps.map { FrameRate(whole: $0) } ?? spec.fps
        spec.durationFrames = p.durationFrames ?? spec.durationFrames
        guard let background = NewDocumentSpec.color(hex: p.background ?? "#FFFFFF") else {
            throw CatalogError.failed(id: "file.new", message: "Pick a valid background color.")
        }
        spec.background = background
        try attempt("file.new") { $0.newDocument(spec) }
        return .object([:])
    }

    /// Add Label (a name) or Remove Label (none), refused as the timeline's menu disables them.
    mutating func label(_ name: String?) throws {
        let trimmed = name.map { String($0.drop { $0.isWhitespace }.reversed().drop { $0.isWhitespace }.reversed()) }
        if trimmed?.isEmpty == true { throw CatalogError.failed(id: "frame.label", message: "Name the label first.") }
        if trimmed == nil, timelineLabels[currentFrame] == nil { throw CatalogError.failed(id: "frame.label", message: "No label at the playhead.") }
        try timelineEdit("frame.label") { $0.setLabel(trimmed) }
    }

    /// A timeline edit, its refusal (`timelineError`) thrown.
    mutating func timelineEdit(_ id: String, _ body: (inout FlareWorkspace) -> Void) throws {
        timelineError = nil
        body(&self)
        if let error = timelineError { throw CatalogError.failed(id: id, message: error) }
    }

    /// Restore's run: a recovered file that doesn't decode changes nothing.
    mutating func restore(_ data: Data) throws {
        switch Self.decodeFile(data) {
        case .success(let document): restoreRecovery(document)
        case .failure(let error): throw CatalogError.failed(id: "recovery.restore", message: error.message)
        }
    }
}
