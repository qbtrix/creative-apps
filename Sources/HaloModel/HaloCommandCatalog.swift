// HaloCommandCatalog.swift (adopt-command-catalog AC-h1): each `HaloCommand` case as a catalog command over
// `HaloProject`, available as `unavailableHelp(for:)` says, running what the window's route runs. File commands
// are `notBuilt` until `HaloHeadless` (AC-h2) runs them; Render starts the open sheet's run with the sheet's
// settings (command-state CS-7). `windowSpecs` are the window's own steps a bare control runs. Linux-safe: no UI imports.
import CoreRaster
import SuiteKernel

extension HaloProject {
    /// One spec per `HaloCommand.allCases` entry, in that order, then the
    /// kernel's `shape.draw` and `tool.shape` (shape-tools HS-6), its eight `fill.*` commands
    /// (gradient-fill HG-7), its nine `stroke.*` commands (stroke-style HK-6), the History panel's
    /// `history.read` and `history.jump` (autosave-history HA-6), `frameRateSpecs` (frame-rates FR-8b), then `windowSpecs`.
    public static let commandSpecs: [CommandSpec<HaloProject>] =
        HaloCommand.allCases.map(spec(for:)) + ShapeCommands.specs(HaloProject.self)
        + GradientCommands.specs(HaloProject.self) + StrokeCommands.specs(HaloProject.self)
        + HistoryCommands.specs(HaloProject.self) + frameRateSpecs + windowSpecs

    /// The render sheet's Choose… and the unsaved alert's Save and Don't Save (CS-7): headless they check
    /// availability and change nothing, since the panel and the held command are the window's.
    static let windowSpecs: [CommandSpec<HaloProject>] = [
        .typed("render.choose-folder", title: "Choose…", summary: "Asks for the folder the open render writes into.", kind: .view,
               params: Param.None.self, schema: ParamSchema.none, example: .object([:]), availability: available(Param.render)) { p, _ in try p.windowStep("render.choose-folder", p.unavailableHelp(for: Param.render)) },
        .typed("file.answer-unsaved", title: "Save Changes", summary: "Answers the unsaved-changes alert: save, then go on, or dontSave and go on.",
               kind: .file, params: Param.Answer.self, schema: obj(["answer": .string(oneOf: Param.answers.map(\.name))]),
               example: .object(["answer": .string("save")]), availability: { $0.unsavedHelp.map(Availability.unavailable) ?? .available }) { p, o in
            try p.windowStep("file.answer-unsaved", p.unsavedHelp, ["answer": .string(o.answer)])
        },
    ]

    /// A window step headless: refuses with `why`, else returns `result` and changes nothing.
    func windowStep(_ id: String, _ why: String?, _ result: [String: JSONValue] = [:]) throws -> JSONValue {
        if let why { throw CatalogError.unavailable(id: id, why: why) }
        return .object(result)
    }

    /// Why the unsaved-changes alert has nothing to answer; nil while there are unsaved edits.
    var unsavedHelp: String? {
        if file.opening { return "A project is opening." }
        return file.unsaved ? nil : "There are no unsaved changes."
    }

    /// New Composition's Create: the sheet's settings over the suggested ones; refused in their problems' words.
    mutating func runNewComposition(_ o: HaloHeadless.NewOptions) throws -> JSONValue {
        if let why = unavailableHelp(for: .newComposition) { throw CatalogError.unavailable(id: "composition.new", why: why) }
        let settings = o.settings(over: suggestedSettings)
        guard newComposition(settings) else { throw CatalogError.failed(id: "composition.new", message: settings.problems.joined(separator: " ")) }
        return .object(["id": .string(selectedCompositionID ?? "")])
    }

    /// Halo's catalog over the project; its history reads the project's steps.
    public static let catalog: CommandCatalog<HaloProject> =
        (try? CommandCatalog(app: "halo", commandSpecs, history: { HaloCatalogSteps(project: $0) })) ?? .empty(app: "halo")

    /// The case `sample`'s availability asks about: the payload's id rebound
    /// to the selected composition, or the selected (else top) layer.
    func availabilityProbe(_ sample: HaloCommand) -> HaloCommand {
        let comp = selectedCompositionID ?? "", layer = selectedLayerID ?? selectedComposition?.layers.first?.id ?? ""
        switch sample {
        case .selectComposition: return .selectComposition(comp)
        case .renameComposition(_, let name): return .renameComposition(comp, name)
        case .selectLayer: return .selectLayer(layer)
        case .renameLayer(_, let name): return .renameLayer(layer, name)
        case .moveLayer(_, let index): return .moveLayer(layer, to: index)
        default: return sample
        }
    }

    /// Runs `command` as catalog command `id`: refuses with its help, then
    /// does what the window's route does; a refusal it records throws.
    mutating func runCommand(_ id: String, _ command: HaloCommand) throws -> JSONValue {
        if let why = unavailableHelp(for: command) { throw CatalogError.unavailable(id: id, why: why) }
        let refusalBefore = refusal, renameBefore = refusedRename
        let result = try perform(id, command)
        if let r = refusal, r != refusalBefore { throw CatalogError.failed(id: id, message: r.message) }
        if let r = refusedRename, r != renameBefore { throw CatalogError.failed(id: id, message: r.problem) }
        return result
    }

    /// The Model call each route in `HaloWindow+*.swift` makes for `command`.
    private mutating func perform(_ id: String, _ command: HaloCommand) throws -> JSONValue {
        switch command {
        case .newComposition: newComposition()
        case .duplicateComposition: if let comp = selectedCompositionID { _ = duplicateComposition(comp) }
        case .deleteComposition: if case .delete(let comp) = compositionDeleteCommand(editingText: false) { _ = deleteComposition(comp) }
        case .selectComposition(let comp): selectComposition(comp)
        case .renameComposition(let comp, let name): _ = renameComposition(comp, to: name)
        case .newLayer(let kind): newLayer(kind)
        case .duplicateLayer: duplicateSelectedLayer()
        case .beginRenameLayer: return .object(["id": .string(selectedLayer?.id ?? ""), "name": .string(selectedLayer?.name ?? "")])
        case .renameLayer(let layer, let name): renameLayer(layer, to: name)
        case .deleteLayer: deleteSelectedLayer()
        case .bringLayerForward: bringSelectedLayerForward()
        case .sendLayerBackward: sendSelectedLayerBackward()
        case .moveLayer(let layer, let index): moveLayer(layer, to: index)
        case .selectLayer(let layer): if let layer { selectLayer(layer) }
        case .playPause: togglePlay(at: 0)
        case .toggleLoop: setLoops(!playback.loops)
        case .nextFrame: stepFrame(by: 1)
        case .previousFrame: stepFrame(by: -1)
        case .goToStart: goToStart()
        case .goToEnd: goToEnd()
        case .setInPoint: _ = setSelectedLayerInPoint()
        case .setOutPoint: _ = setSelectedLayerOutPoint()
        case .scrub(let frame): if scrubChanges(to: frame) { scrub(to: frame) }
        case .tick(let now): if tickChanges(now: now) { _ = tick(now: now) }
        case .setProperty(let p, let value): setProperty(p, to: value)
        case .setPropertyText(let p, let text): setProperty(p, text: text)
        case .endPropertyScrub: endPropertyScrub()
        case .toggleAnimation(let p): toggleAnimation(p)
        case .toggleKey(let p): toggleKey(p)
        case .setParent(let parent): setParent(parent)
        case .setBlendMode(let mode): setSelectedLayerBlendMode(mode)
        case .beginViewerDrag(let x, let y): beginViewerDrag(at: HaloPoint(x: x, y: y))
        case .moveViewerDrag(let x, let y): moveViewerDrag(to: HaloPoint(x: x, y: y))
        case .endViewerDrag: endViewerDrag()
        case .cancelViewerDrag: cancelViewerDrag()
        case .undo: undo()
        case .redo: redo()
        case .save, .saveAs, .open, .openRecent:
            throw CatalogError.notBuilt(id: id, feature: "adopt-command-catalog AC-h2")
        case .startRender(let settings):
            setRenderSettings(settings)
            guard let started = startRender() else { throw CatalogError.failed(id: id, message: renderOutcomeText ?? "The render can't start.") }
            let plan = started.plan
            return .object(["frames": .number(Double(plan.frames.count)), "width": .number(Double(plan.width)), "height": .number(Double(plan.height))])
        case .setEasing(let preset): setEasing(preset)
        case .selectKey(let key, let extending): selectKey(key, extending: extending)
        case .selectLaneKeys(let layer, let frame, let extending): selectLaneKeys(layerID: layer, frame: frame, extending: extending)
        case .clearKeySelection: clearKeySelection()
        case .deleteKeys: deleteKeys()
        case .setCustomEasing(let easing): setCustomEasing(easing, coalesceKey: pickedSegment.map { "\($0.key.layerID).easing" })
        case .moveEasingHandle(let index, let x, let y): moveEasingHandle(index == 0 ? .first : .second, to: HaloPoint(x: x, y: y))
        case .endEasingDrag: endCoalescing()
        case .pickLaneKeys(let layer, let frame, let mode): pickLaneKeys(layerID: layer, frame: frame, mode: mode)
        case .selectAllKeys: selectAllKeys()
        case .moveKeys(let frames, let dragStart): moveKeys(by: frames, dragStart: dragStart)
        case .endKeyDrag: endKeyDrag()
        case .renderFrame: renderCurrentFrame()
        case .openRenderSheet: beginRender(HaloRenderSettings(format: .pngSequence))
        case .cancelRender: cancelRender()
        case .closeRenderSheet: dismissRender()
        case .setText(let text): setText(text)
        case .setFontSize(let size): setFontSize(size)
        case .endTextSizeScrub: endTextSizeScrub()
        case .setLayerColor(let color): setLayerColor(color)
        }
        return .object([:])
    }

    /// The spec for `c`'s case; `c` is its sample, the example's source.
    static func spec(for c: HaloCommand) -> CommandSpec<HaloProject> {
        switch c {
        case .newComposition: .typed("composition.new", title: "New Composition", summary: "Adds a composition with the sheet's settings, else the suggested ones, and selects it.",
                                     kind: .edit, params: HaloHeadless.NewOptions.self, schema: Param.newComposition, example: .object([:]), availability: available(c)) { p, o in try p.runNewComposition(o) }
        case .duplicateComposition: plain(c, "composition.duplicate", "Duplicate Composition", .edit, "Copies the selected composition.")
        case .deleteComposition: plain(c, "composition.delete", "Delete Composition", .edit, "Deletes the selected composition; one always stays.")
        case .selectComposition: typed(c, "composition.select", "Select Composition", .view, "Selects a composition.", Param.ID.self, obj(["id": Param.id]), ["id": .string("comp-1")]) { .selectComposition($0.id) }
        case .renameComposition: typed(c, "composition.rename", "Rename Composition", .edit, "Renames a composition.", Param.Rename.self, obj(["id": Param.id, "name": Param.name]), ["id": .string("comp-1"), "name": .string("Intro")]) { .renameComposition($0.id, $0.name) }
        case .newLayer: typed(c, "layer.new", "New Layer", .edit, "Adds a layer of a kind on top and selects it.", Param.Kind.self, obj(["kind": .string(oneOf: HaloLayerKind.allCases.map(\.rawValue))]), ["kind": .string("solid")]) { .newLayer($0.kind) }
        case .duplicateLayer: plain(c, "layer.duplicate", "Duplicate Layer", .edit, "Copies the selected layer above it.")
        case .beginRenameLayer: .typed("layer.rename-begin", title: "Rename Layer…", summary: "The selected layer's id and name, for a rename.", kind: .query, params: Param.None.self, schema: ParamSchema.none, result: obj(["id": Param.id, "name": Param.name]), example: .object([:]), availability: available(c)) { p, _ in try p.runCommand("layer.rename-begin", c) }
        case .renameLayer: typed(c, "layer.rename", "Rename Layer", .edit, "Renames a layer.", Param.Rename.self, obj(["id": Param.id, "name": Param.name]), ["id": .string("comp-1-layer-2"), "name": .string("Ball 2")]) { .renameLayer($0.id, $0.name) }
        case .deleteLayer: plain(c, "layer.delete", "Delete Layer", .edit, "Deletes the selected layer.")
        case .bringLayerForward: plain(c, "layer.bring-forward", "Bring Forward", .edit, "Moves the selected layer up one.")
        case .sendLayerBackward: plain(c, "layer.send-backward", "Send Backward", .edit, "Moves the selected layer down one.")
        case .moveLayer: typed(c, "layer.move", "Move Layer", .edit, "Moves a layer to a place in the stack, 0 on top.", Param.Move.self, obj(["id": Param.id, "index": .integer(minimum: 0)]), ["id": .string("comp-1-layer-2"), "index": .number(1)]) { .moveLayer($0.id, to: $0.index) }
        case .selectLayer: typed(c, "layer.select", "Select Layer", .view, "Selects a layer.", Param.ID.self, obj(["id": Param.id]), ["id": .string("comp-1-layer-2")]) { .selectLayer($0.id) }
        case .playPause: plain(c, "animation.play-pause", "Play/Pause", .view, "Starts or stops playback.")
        case .toggleLoop: plain(c, "animation.loop", "Loop", .view, "Turns looping playback on or off.")
        case .nextFrame: plain(c, "animation.next-frame", "Next Frame", .view, "Moves the playhead one frame on.")
        case .previousFrame: plain(c, "animation.previous-frame", "Previous Frame", .view, "Moves the playhead one frame back.")
        case .goToStart: plain(c, "animation.go-to-start", "Go to Start", .view, "Moves the playhead to the first frame.")
        case .goToEnd: plain(c, "animation.go-to-end", "Go to End", .view, "Moves the playhead to the last frame.")
        case .setInPoint: plain(c, "animation.set-in-point", "Set In Point", .edit, "Starts the selected layer at the playhead.")
        case .setOutPoint: plain(c, "animation.set-out-point", "Set Out Point", .edit, "Ends the selected layer at the playhead.")
        case .scrub: typed(c, "timeline.scrub", "Move Playhead", .view, "Moves the playhead to a frame.", Param.Frame.self, obj(["frame": .integer(minimum: 0)]), ["frame": .number(12)]) { .scrub($0.frame) }
        case .tick: typed(c, "animation.tick", "Play Frame", .view, "Advances playback to a time in seconds.", Param.Time.self, obj(["now": .number(minimum: 0)]), ["now": .number(0.5)]) { .tick($0.now) }
        case .setProperty: typed(c, "inspector.set-property", "Change Property", .edit, "Sets a transform property of the selected layer at the playhead.", Param.PropertyValue.self, obj(["property": Param.property, "value": .number()]), ["property": .string("x"), "value": .number(100)]) { .setProperty($0.property, $0.value) }
        case .setPropertyText: typed(c, "inspector.set-property-text", "Type Property", .edit, "Sets a transform property from typed text.", Param.PropertyText.self, obj(["property": Param.property, "text": .string(maxLength: 64)]), ["property": .string("x"), "text": .string("100")]) { .setPropertyText($0.property, $0.text) }
        case .endPropertyScrub: plain(c, "inspector.end-property-scrub", "End Change", .view, "Ends a property scrub, so the next change is its own step.")
        case .toggleAnimation: typed(c, "inspector.toggle-animation", "Animate Property", .edit, "Turns a property's animation on or off.", Param.PropertyOnly.self, obj(["property": Param.property]), ["property": .string("x")]) { .toggleAnimation($0.property) }
        case .toggleKey: typed(c, "inspector.toggle-key", "Key Property", .edit, "Adds or removes a property's key at the playhead.", Param.PropertyOnly.self, obj(["property": Param.property]), ["property": .string("x")]) { .toggleKey($0.property) }
        case .setParent: typed(c, "inspector.set-parent", "Set Parent", .edit, "Makes the selected layer follow a layer; no id clears it.", Param.Parent.self, obj(["id": .optional(Param.id)]), ["id": .string("comp-1-layer-1")]) { .setParent($0.id) }
        case .setBlendMode: typed(c, "inspector.set-blend-mode", "Change Blend Mode", .edit, "Sets the selected layer's blend mode.", Param.Blend.self, obj(["mode": .string(oneOf: BlendMode.allCases.map(\.rawValue))]), ["mode": .string("multiply")]) { .setBlendMode($0.mode) }
        case .beginViewerDrag: typed(c, "viewer.drag-begin", "Drag Layer", .view, "Picks the top layer under a point and starts dragging it.", Param.Point.self, Param.point, ["x": .number(10), "y": .number(10)]) { .beginViewerDrag(x: $0.x, y: $0.y) }
        case .moveViewerDrag: typed(c, "viewer.drag-move", "Move Drag", .view, "Moves the drag's preview to a point.", Param.Point.self, Param.point, ["x": .number(20), "y": .number(20)]) { .moveViewerDrag(x: $0.x, y: $0.y) }
        case .endViewerDrag: plain(c, "viewer.drag-end", "Move", .edit, "Ends the drag, moving the layer as one step.")
        case .cancelViewerDrag: plain(c, "viewer.drag-cancel", "Cancel Drag", .view, "Drops the drag and its preview.")
        case .undo: plain(c, "edit.undo", "Undo", .view, "Goes back one step.")
        case .redo: plain(c, "edit.redo", "Redo", .view, "Goes forward one undone step.")
        case .save: plain(c, "file.save", "Save", .file, "Saves the project.")
        case .saveAs: plain(c, "file.save-as", "Save As…", .file, "Saves the project under a new name.")
        case .open: plain(c, "file.open", "Open…", .file, "Opens a project.")
        case .openRecent: typed(c, "file.open-recent", "Open Recent", .file, "Opens a recent project.", Param.Path.self, obj(["path": .string()]), ["path": .string("/tmp/Bounce.halo")]) { .openRecent($0.path) }
        case .setEasing: typed(c, "animation.easing", "Keyframe Easing", .edit, "Sets the picked keys' easing to a preset.", Param.Preset.self, obj(["preset": .string(oneOf: HaloEasingPreset.allCases.map(\.rawValue))]), ["preset": .string("easeInOut")]) { try .setEasing(decoded(HaloEasingPreset(rawValue: $0.preset))) }
        case .selectKey: typed(c, "easing.select-key", "Select Key", .view, "Picks a key, or adds it to the pick.", Param.Key.self, obj(["layerID": Param.id, "property": Param.property, "frame": .integer(minimum: 0), "extending": .boolean]), ["layerID": .string("comp-1-layer-2"), "property": .string("x"), "frame": .number(0), "extending": .bool(false)]) { .selectKey(HaloKeyRef(layerID: $0.layerID, property: $0.property, frame: $0.frame), extending: $0.extending) }
        case .selectLaneKeys: typed(c, "easing.select-lane-keys", "Select Keys", .view, "Picks a layer's keys at a frame.", Param.Lane.self, obj(["layerID": Param.id, "frame": .integer(minimum: 0), "extending": .boolean]), ["layerID": .string("comp-1-layer-2"), "frame": .number(0), "extending": .bool(false)]) { .selectLaneKeys(layerID: $0.layerID, frame: $0.frame, extending: $0.extending) }
        case .clearKeySelection: plain(c, "easing.clear-selection", "Clear Key Selection", .view, "Unpicks every key.")
        case .deleteKeys: plain(c, "easing.delete-keys", "Delete Keyframes", .edit, "Deletes the picked keys.")
        case .setCustomEasing: typed(c, "easing.set-custom", "Custom Easing", .edit, "Sets the picked keys' easing to a cubic curve.", Param.Bezier.self, obj(["x1": Param.unit, "y1": .number(), "x2": Param.unit, "y2": .number()]), ["x1": .number(0.42), "y1": .number(0), "x2": .number(1), "y2": .number(1)]) { .setCustomEasing(.cubicBezier(x1: $0.x1, y1: $0.y1, x2: $0.x2, y2: $0.y2)) }
        case .moveEasingHandle: typed(c, "easing.move-handle", "Move Easing Handle", .edit, "Moves the first (0) or second (1) easing handle.", Param.Handle.self, obj(["index": .integer(minimum: 0, maximum: 1), "x": Param.unit, "y": .number()]), ["index": .number(0), "x": .number(0.3), "y": .number(0)]) { .moveEasingHandle(index: $0.index, x: $0.x, y: $0.y) }
        case .endEasingDrag: plain(c, "easing.end-drag", "End Easing Change", .view, "Ends an easing drag, so the next change is its own step.")
        case .pickLaneKeys: typed(c, "timeline.pick-keys", "Select Keys", .view, "Picks a layer's keys at a frame: replace, extend (Shift) or toggle (Command); no frame clears the pick.", Param.PickKeys.self, obj(["layerID": Param.id, "frame": .optional(.integer(minimum: 0)), "mode": .string(oneOf: Param.modes.map(\.name))]), ["layerID": .string("comp-1-layer-2"), "frame": .number(0), "mode": .string("replace")]) { try .pickLaneKeys(layerID: $0.layerID, frame: $0.frame, mode: decoded(Param.pick($0.mode))) }
        case .selectAllKeys: plain(c, "timeline.select-all-keys", "Select All Keys", .view, "Picks every key of the selected composition, hidden layers included.")
        case .moveKeys: typed(c, "timeline.move-keys", "Move Keyframes", .edit, "Moves the picked keys by frames since the last move; moves of one drag share its dragStart and are one step.", Param.MoveKeys.self, obj(["by": .integer(), "dragStart": .integer(minimum: 0)]), ["by": .number(6), "dragStart": .number(0)]) { .moveKeys(by: $0.by, dragStart: $0.dragStart) }
        case .endKeyDrag: plain(c, "timeline.end-key-drag", "End Key Drag", .view, "Ends a key drag, so the next move is its own step.")
        case .renderFrame: plain(c, "render.frame", "Render Frame", .view, "Renders the frame at the playhead for the viewer.")
        case .openRenderSheet: plain(c, "render.open-sheet", "Render…", .view, "Opens the render settings.")
        case .startRender: typed(c, "render.start", "Render", .file, "Starts the open render with the sheet's format and size.", Param.Render.self, obj(["format": .string(oneOf: HaloRenderSettings.Format.allCases.map(\.rawValue)), "halfSize": .optional(.boolean)]), ["format": .string("pngSequence")]) { try .startRender(HaloRenderSettings(format: decoded(.init(rawValue: $0.format)), halfSize: $0.halfSize ?? false)) }
        case .cancelRender: plain(c, "render.cancel", "Cancel Render", .view, "Cancels the running render, or closes its settings.")
        case .closeRenderSheet: plain(c, "render.close-sheet", "Close Render", .view, "Closes the render settings.")
        case .setText: typed(c, "text.set", "Edit Text", .edit, "Sets the selected text layer's text.", Param.Text.self, obj(["text": .string()]), ["text": .string("Hello")]) { .setText($0.text) }
        case .setFontSize: typed(c, "text.set-size", "Change Text Size", .edit, "Sets the selected text layer's font size.", Param.Size.self, obj(["size": .number(minimum: 1)]), ["size": .number(48)]) { .setFontSize($0.size) }
        case .endTextSizeScrub: plain(c, "text.end-size-scrub", "End Text Size Change", .view, "Ends a text size scrub.")
        case .setLayerColor: typed(c, "text.set-color", "Change Color", .edit, "Sets the selected layer's color, each channel 0 to 1.", HaloLayerColor.self, obj(["red": Param.unit, "green": Param.unit, "blue": Param.unit]), ["red": .number(1), "green": .number(0), "blue": .number(0)]) { .setLayerColor($0) }
        }
    }

    /// A spec with no params: `c` is what it asks about and runs.
    private static func plain(_ c: HaloCommand, _ id: String, _ title: String, _ kind: CommandKind, _ summary: String) -> CommandSpec<HaloProject> {
        .typed(id, title: title, summary: summary, kind: kind, params: Param.None.self, schema: ParamSchema.none, example: .object([:]), availability: available(c)) { p, _ in try p.runCommand(id, c) }
    }

    /// A spec whose params `P` build the case it runs; `sample`'s probe is what availability asks about.
    private static func typed<P: Decodable & Sendable>(
        _ sample: HaloCommand, _ id: String, _ title: String, _ kind: CommandKind, _ summary: String, _ params: P.Type,
        _ schema: ParamSchema, _ example: [String: JSONValue], _ make: @escaping @Sendable (P) throws -> HaloCommand
    ) -> CommandSpec<HaloProject> {
        .typed(id, title: title, summary: summary, kind: kind, params: P.self, schema: schema, example: .object(example), availability: available(sample)) { p, params in try p.runCommand(id, make(params)) }
    }

    private static func available(_ sample: HaloCommand) -> @Sendable (HaloProject) -> Availability {
        { p in p.unavailableHelp(for: p.availabilityProbe(sample)).map(Availability.unavailable) ?? .available }
    }

    /// A raw value the schema's `enum` already checked.
    private static func decoded<T>(_ value: T?) throws -> T {
        guard let value else { throw CatalogError.malformedParams(id: "halo", [SchemaIssue(path: "", message: "unknown case")]) }
        return value
    }

    fileprivate static func obj(_ properties: [String: ParamSchema]) -> ParamSchema { .object(properties, required: properties.keys.sorted()) }
}

/// What the catalog reads from a project's history: its step names and
/// whether the file has unsaved edits.
struct HaloCatalogSteps: HistoryReading {
    let project: HaloProject
    var canUndo: Bool { !project.history.undo.isEmpty }; var canRedo: Bool { !project.history.redo.isEmpty }
    var undoName: String? { project.history.undo.last?.name }; var redoName: String? { project.history.redo.last?.name }
    var isDirty: Bool { project.file.unsaved }
}

extension HaloCommand {
    /// The catalog id this case runs as ("layer.delete").
    public var commandID: String { HaloProject.spec(for: self).id }
}

/// The catalog's param types and shared schemas.
private enum Param {
    static let id = ParamSchema.string("A composition or layer id.", maxLength: 64)
    static let name = ParamSchema.string(maxLength: 255)
    static let unit = ParamSchema.number(minimum: 0, maximum: 1)
    static let property = ParamSchema.string(oneOf: HaloProperty.allCases.map(\.rawValue))
    static let point = HaloProject.obj(["x": .number(), "y": .number()])

    struct None: Decodable, Sendable {}; struct Kind: Decodable, Sendable { var kind: HaloLayerKind }
    struct ID: Decodable, Sendable { var id: String }; struct Rename: Decodable, Sendable { var id, name: String }
    struct Frame: Decodable, Sendable { var frame: Int }; struct Time: Decodable, Sendable { var now: Double }
    struct PropertyValue: Decodable, Sendable { var property: HaloProperty; var value: Double }; struct PropertyText: Decodable, Sendable { var property: HaloProperty; var text: String }
    struct PropertyOnly: Decodable, Sendable { var property: HaloProperty }; struct Move: Decodable, Sendable { var id: String; var index: Int }
    struct Parent: Decodable, Sendable { var id: String? }; struct Blend: Decodable, Sendable { var mode: BlendMode }
    struct Point: Decodable, Sendable { var x, y: Double }; struct Path: Decodable, Sendable { var path: String }
    struct Preset: Decodable, Sendable { var preset: String }
    struct Key: Decodable, Sendable { var layerID: String; var property: HaloProperty; var frame: Int; var extending: Bool }
    struct Lane: Decodable, Sendable { var layerID: String; var frame: Int; var extending: Bool }
    struct PickKeys: Decodable, Sendable { var layerID: String; var frame: Int?; var mode: String }
    struct MoveKeys: Decodable, Sendable { var by, dragStart: Int }
    static let modes: [(name: String, pick: Pick)] = [("replace", .replace), ("extend", .extend), ("toggle", .toggle)]
    static func pick(_ name: String) -> Pick? { modes.first { $0.name == name }?.pick }
    struct Bezier: Decodable, Sendable { var x1, y1, x2, y2: Double }; struct Handle: Decodable, Sendable { var index: Int; var x, y: Double }
    struct Render: Decodable, Sendable { var format: String; var halfSize: Bool? }
    static let render = HaloCommand.startRender(HaloRenderSettings(format: .pngSequence))
    static let newComposition = ParamSchema.object(["name": name, "width": size, "height": size, "seconds": .number(minimum: 0),
                                                     "fps": .integer(minimum: 1)], required: [])
    static let size = ParamSchema.integer(minimum: CompositionSettings.sizeRange.lowerBound, maximum: CompositionSettings.sizeRange.upperBound)
    /// The unsaved alert's answers a control sends: the kernel's, but Cancel, which only closes it.
    struct Answer: Decodable, Sendable { var answer: String }
    static let answers: [(name: String, answer: UnsavedPrompt.Answer)] = [("save", .save), ("dontSave", .dontSave)]
    struct Text: Decodable, Sendable { var text: String }; struct Size: Decodable, Sendable { var size: Double }
}
