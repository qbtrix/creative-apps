// FlareDocumentCommands+Catalog.swift (adopt-command-catalog AC-f1): one catalog spec per FlareCore command id in
// CommandRegistry.builtIn, over FlareWorkspace. A spec's params are the command's own JSON (what the registry's
// envelope carries as "params"), its schema is SchemaProbe's unless `coreSchemaOverrides` has one, it is available
// when its example runs on a copy of the workspace, and it runs through the workspace's CommandEngine as one undo step.
// Catalog ids allow no capitals, so a FlareCore id keeps its words in kebab case: layer.setFlags is layer.set-flags.
// The stage and PNG frames don't draw masks or mattes yet while SVG and Lottie write them, so the commands that make
// or change one (`notDrawnOnStage`) are unavailable with `masksNotDrawn` rather than export a different picture.
import FlareCore
import SuiteKernel

extension FlareWorkspace {
    /// One spec per `CommandRegistry.builtIn` id; each example runs in order on `newDocument()`.
    public static let coreCommands: [CommandSpec<FlareWorkspace>] = coreExamples.map { $0.spec }

    /// `coreID` as a catalog id: each capital becomes "-" and its lower case (colorKey.set is color-key.set).
    public static func catalogID(_ coreID: String) -> String {
        coreID.reduce(into: "") { id, c in id += c.isUppercase ? "-" + c.lowercased() : String(c) }
    }

    /// Runs `command` on the engine as one undo step; a refusal throws the message `layerError` reads.
    mutating func performCore(_ command: some FlareCore.Command, id: String) throws(CatalogError) {
        apply(command)
        if let error = layerError { throw .failed(id: id, message: error.message) }
    }

    /// FlareCore ids that make or change a mask or matte, which the stage and PNG frames can't draw yet.
    public static let notDrawnOnStage: Set<String> = ["mask.add", "mask.set", "mask.setMatte"]
    /// Why `notDrawnOnStage` commands are unavailable.
    public static let masksNotDrawn = "Flare's stage and PNG frames don't draw masks or mattes yet, so this would "
        + "export a different picture from the one on the stage. Removing or reordering a mask still works."

    /// The dry run: `example` on a copy of `workspace`; unavailable with the engine's message when it is refused.
    /// A `notDrawnOnStage` id is unavailable with `masksNotDrawn` whenever a document is open.
    static func dryRun<C: FlareCore.Command>(_ example: C, on workspace: FlareWorkspace) -> Availability {
        if notDrawnOnStage.contains(C.id), workspace.document != nil { return .unavailable(masksNotDrawn) }
        var copy = workspace
        copy.apply(example)
        return copy.layerError.map { .unavailable($0.message) } ?? .available
    }
}

/// A FlareCore command's example, kept typed so its spec decodes and runs as that command type.
struct CoreExample: Sendable {
    let spec: CommandSpec<FlareWorkspace>
    init<C: FlareCore.Command>(_ example: C) {
        let id = FlareWorkspace.catalogID(C.id)
        spec = .typed(id, title: example.label, summary: "FlareCore's \(C.id) on the open document.", kind: .edit,
                      params: C.self, schema: coreSchemaOverrides[C.id],
                      example: (try? JSONValue(encoding: example)) ?? .null,
                      availability: { FlareWorkspace.dryRun(example, on: $0) },
                      run: { (workspace: inout FlareWorkspace, command: C) throws -> JSONValue in
                          try workspace.performCore(command, id: id)
                          return .object([:])
                      })
    }
}

// MARK: - Examples

private let s1 = LayerOwner.scene("scene-1"), square = [FlareCore.Point(x: 0, y: 0), FlareCore.Point(x: 40, y: 0),
                                                        FlareCore.Point(x: 40, y: 40), FlareCore.Point(x: 0, y: 40)]
private let red = FlareCore.Color(r: 1, g: 0, b: 0), idle = MachineState(id: "idle", name: "Idle", sceneID: "scene-1",
                                                                       startFrame: 0, endFrame: 10)

/// One example per id, in an order that runs on `newDocument()`: adds, then edits, then removals.
let coreExamples: [CoreExample] = [
    CoreExample(AddScene(scene: FlareScene(id: "scene-2", name: "Scene 2", layers: [Layer(id: "layer-2", name: "Back")]))),
    CoreExample(RenameScene(sceneID: "scene-2", name: "Intro")),
    CoreExample(SetSceneTiming(sceneID: "scene-2", fps: 30, durationFrames: 60)),
    CoreExample(SetSceneCanvas(sceneID: "scene-2", width: 640, height: 480, background: red)),
    CoreExample(ReorderScene(sceneID: "scene-2", toIndex: 0)),
    CoreExample(SetMetadata(metadata: Metadata(title: "Demo"))),
    CoreExample(SetFrameLabel(sceneID: "scene-1", name: "start", frame: 0)),
    CoreExample(AddGuide(sceneID: "scene-1", axis: .vertical, position: 100)),
    CoreExample(MoveGuide(sceneID: "scene-1", index: 0, position: 120)),
    CoreExample(AddSwatch(name: "Ink", color: red)),
    CoreExample(RenameSwatch(name: "Ink", newName: "Night")),
    CoreExample(SetSwatchColor(name: "Night", color: FlareCore.Color(r: 0.1, g: 0.1, b: 0.2))),
    CoreExample(AddLayer(owner: s1, layer: Layer(id: "layer-1", name: "Layer 1"))),
    CoreExample(RenameLayer(owner: s1, layerID: "layer-1", name: "Hero")),
    CoreExample(AddShape(owner: s1, layerID: "layer-1", shape: FlareShape(points: square))),
    CoreExample(SetShapeFill(owner: s1, layerID: "layer-1", index: 0, fill: .solid(red))),
    CoreExample(SetShapeStroke(owner: s1, layerID: "layer-1", index: 0, stroke: Stroke(width: 2, join: .round))),
    CoreExample(SetShapePath(owner: s1, layerID: "layer-1", index: 0, path: FlarePath(polyline: square, closed: true),
                             points: square)),
    CoreExample(TranslateShape(owner: s1, layerID: "layer-1", index: 0, dx: 10, dy: 5)),
    CoreExample(SetKeyframe(owner: s1, layerID: "layer-1", property: "x", keyframe: FlareCore.Keyframe(frame: 0, value: 0))),
    CoreExample(MoveKeyframe(owner: s1, layerID: "layer-1", property: "x", from: 0, to: 4)),
    CoreExample(SetKeyframeEasing(owner: s1, layerID: "layer-1", property: "x", frame: 4,
                                  easing: .cubicBezier(x1: 0.4, y1: 0, x2: 0.2, y2: 1))),
    CoreExample(ShiftKeyframes(owner: s1, layerID: "layer-1", fromFrame: 0, toFrame: 10, delta: 2)),
    CoreExample(RemoveKeyframe(owner: s1, layerID: "layer-1", property: "x", frame: 6)),
    CoreExample(SetColorKeyframe(owner: s1, layerID: "layer-1", target: .fill(shape: 0), frame: 0, value: red)),
    CoreExample(MoveColorKeyframes(owner: s1, layerID: "layer-1", target: .fill(shape: 0), frames: [0], by: 3)),
    CoreExample(RemoveColorKeyframe(owner: s1, layerID: "layer-1", target: .fill(shape: 0), frame: 3)),
    CoreExample(SetShapeKeyframe(owner: s1, layerID: "layer-1", shape: 0, frame: 0,
                                 path: FlarePath(polyline: square, closed: true), easing: .hold)),
    CoreExample(RemoveShapeKeyframe(owner: s1, layerID: "layer-1", shape: 0, frame: 0)),
    CoreExample(AddTextShape(owner: s1, layerID: "layer-1", text: TextShape(
        string: "Hello", fontFamily: "Helvetica", fontSize: 24, position: FlareCore.Point(x: 10, y: 10)))),
    CoreExample(SetTextString(owner: s1, layerID: "layer-1", index: 0, string: "Hello world")),
    CoreExample(SetTextFont(owner: s1, layerID: "layer-1", index: 0, family: "Courier", size: 18)),
    CoreExample(ApplyTextStyle(owner: s1, layerID: "layer-1", textIndex: 0, range: 0..<5, style: TextRunStyle(weight: 700))),
    CoreExample(ClearTextStyle(owner: s1, layerID: "layer-1", textIndex: 0, range: 0..<5)),
    CoreExample(EditTextString(owner: s1, layerID: "layer-1", textIndex: 0, replacing: 0..<5, with: "Howdy")),
    CoreExample(SetParagraphStyle(owner: s1, layerID: "layer-1", textIndex: 0, paragraph: ParagraphStyle(alignment: .center))),
    CoreExample(SetTextOnPath(owner: s1, layerID: "layer-1", textIndex: 0,
                              onPath: TextOnPath(path: FlarePath(polyline: square, closed: false)))),
    CoreExample(AddSymbol(symbol: Symbol(id: "symbol-1", name: "Star"))),
    CoreExample(RenameSymbol(symbolID: "symbol-1", name: "Spark")),
    CoreExample(DuplicateLayer(owner: s1, layerID: "layer-1")), // before the instance, so symbol.remove finds none
    CoreExample(AddLayerMask(owner: s1, layerID: "layer-1", mask: LayerMask(path: FlarePath(polyline: square, closed: true)))),
    CoreExample(SetLayerMask(owner: s1, layerID: "layer-1", index: 0,
                             mask: LayerMask(path: FlarePath(polyline: square, closed: true), mode: .subtract, feather: 2))),
    CoreExample(MoveLayerMask(owner: s1, layerID: "layer-1", from: 0, to: 0)),
    CoreExample(SetTrackMatte(owner: s1, layerID: "layer-1", matte: TrackMatte(sourceLayerID: "layer-1-copy", kind: .luma))),
    CoreExample(SetLayerParent(owner: s1, layerID: "layer-1", parentID: "layer-1-copy")),
    CoreExample(AddInstance(owner: s1, layerID: "layer-1", instance: Instance(symbolID: "symbol-1"))),
    CoreExample(SetInstanceTransform(owner: s1, layerID: "layer-1", index: 0, transform: Transform(x: 5, y: 5))),
    CoreExample(SetInstancePlayback(owner: s1, layerID: "layer-1", index: 0, firstFrame: 2, loop: .playOnce)),
    CoreExample(SetLayerFlags(owner: s1, layerID: "layer-1", isVisible: false)),
    CoreExample(ReorderLayer(owner: s1, layerID: "layer-1", toIndex: 0)),
    CoreExample(ConvertToSymbol(sceneID: "scene-2", layerIDs: ["layer-2"], symbolID: "symbol-2", name: "Back")),
    CoreExample(AddStateMachine(id: "machine-1", name: "Main", firstState: idle)),
    CoreExample(RenameStateMachine(machineID: "machine-1", name: "Button")),
    CoreExample(AddMachineState(machineID: "machine-1", state: MachineState(id: "hover", name: "Hover", sceneID: "scene-1",
                                                                           startFrame: 11, endFrame: 20))),
    CoreExample(UpdateMachineState(machineID: "machine-1", state: MachineState(id: "hover", name: "Hover",
                                                                              sceneID: "scene-1", startFrame: 11, endFrame: 24))),
    CoreExample(SetInitialState(machineID: "machine-1", stateID: "hover")),
    CoreExample(AddMachineInput(machineID: "machine-1", input: MachineInput(name: "hovered", defaultValue: .bool(false)))),
    CoreExample(UpdateMachineInput(machineID: "machine-1", input: MachineInput(name: "hovered", defaultValue: .bool(true)))),
    CoreExample(AddTransition(machineID: "machine-1", transition: FlareTransition(
        from: "idle", to: "hover", trigger: "enter", conditions: [Condition(input: "hovered", op: .equal, value: .bool(true))]))),
    CoreExample(UpdateTransition(machineID: "machine-1", index: 0, transition: FlareTransition(from: "hover", to: "idle",
                                                                                               trigger: "leave"))),
    CoreExample(RemoveTransition(machineID: "machine-1", index: 0)),
    CoreExample(RemoveMachineInput(machineID: "machine-1", name: "hovered")),
    CoreExample(RemoveMachineState(machineID: "machine-1", stateID: "idle")),
    CoreExample(RemoveStateMachine(machineID: "machine-1")),
    CoreExample(RemoveShape(owner: s1, layerID: "layer-1", index: 0)),
    CoreExample(RemoveLayerMask(owner: s1, layerID: "layer-1", index: 0)),
    CoreExample(RemoveTextShape(owner: s1, layerID: "layer-1", index: 0)),
    CoreExample(RemoveInstance(owner: s1, layerID: "layer-1", index: 0)),
    CoreExample(RemoveSymbol(symbolID: "symbol-1")),
    CoreExample(RemoveGuide(sceneID: "scene-1", index: 0)),
    CoreExample(RemoveFrameLabel(sceneID: "scene-1", name: "start")),
    CoreExample(RemoveSwatch(name: "Night")),
    CoreExample(RemoveLayer(owner: s1, layerID: "layer-1")),
    CoreExample(RemoveScene(sceneID: "scene-2")),
]

/// The history a catalog over FlareWorkspace reads: the engine's undo and redo, named without "Undo " and "Redo ".
public struct FlareCoreHistory: HistoryReading {
    public let canUndo: Bool, canRedo: Bool, undoName: String?, redoName: String?, isDirty: Bool
    public init(_ workspace: FlareWorkspace) {
        (canUndo, canRedo, isDirty) = (workspace.canUndo, workspace.canRedo, workspace.isDirty)
        (undoName, redoName) = (workspace.undoName, workspace.redoName)
    }
}

// MARK: - Schemas the probe can't read

/// Schemas for FlareCore ids whose probe stops early: every layer command reads its owner (sceneID or symbolID) flat
/// from the params, and LayerOwner refuses the probe's sample, which names both.
let coreSchemaOverrides: [String: ParamSchema] = {
    let i = ParamSchema.integer(), n = ParamSchema.number(), s = ParamSchema.string()
    let range = ParamSchema.array(of: i, minItems: 2, maxItems: 2), target = SchemaProbe.schema(of: TrackTarget.self)
    func probe<T: Decodable>(_ t: T.Type) -> ParamSchema { SchemaProbe.schema(of: t) }
    func layer(_ p: [String: ParamSchema], layerID: Bool = true) -> ParamSchema {
        var all = p.merging(["sceneID": .optional(s), "symbolID": .optional(s)]) { a, _ in a }
        if layerID { all["layerID"] = s }
        return .object(all, required: all.keys.sorted())
    }
    return [
        "layer.add": layer(["layer": probe(Layer.self), "index": .optional(i)], layerID: false),
        "layer.remove": layer([:]), "layer.duplicate": layer([:]), "layer.rename": layer(["name": s]),
        "layer.setFlags": layer(["isVisible": .optional(.boolean), "isLocked": .optional(.boolean)]),
        "layer.reorder": layer(["toIndex": i]),
        "layer.setParent": layer(["parentID": .optional(s)]),
        "keyframe.set": layer(["property": s, "keyframe": probe(FlareCore.Keyframe.self)]),
        "keyframe.move": layer(["property": s, "from": i, "to": i]),
        "keyframe.remove": layer(["property": s, "frame": i]),
        "keyframe.setEasing": layer(["property": s, "frame": i, "easing": FlareCore.Easing.paramSchema]),
        "keyframe.shift": layer(["fromFrame": i, "toFrame": i, "delta": i]),
        "shape.add": layer(["shape": probe(FlareCore.Shape.self)]), "shape.remove": layer(["index": i]),
        "shape.setFill": layer(["index": i, "fill": Fill.paramSchema]),
        "shape.setStroke": layer(["index": i, "stroke": .optional(probe(Stroke.self))]),
        "shape.setPath": layer(["index": i, "path": .optional(probe(FlareCore.Path.self)),
                                "points": .array(of: probe(FlareCore.Point.self))]),
        "shape.translate": layer(["index": i, "dx": n, "dy": n]),
        "text.add": layer(["text": probe(TextShape.self)]), "text.remove": layer(["index": i]),
        "text.setString": layer(["index": i, "string": s]),
        "text.setFont": layer(["index": i, "family": s, "size": n]),
        "instance.add": layer(["instance": probe(Instance.self)]), "instance.remove": layer(["index": i]),
        "instance.setTransform": layer(["index": i, "transform": probe(Transform.self)]),
        "instance.setPlayback": layer(["index": i, "firstFrame": i, "loop": Instance.LoopMode.paramSchema]),
        "text.applyStyle": layer(["textIndex": i, "range": range, "style": probe(TextRunStyle.self)]),
        "text.clearStyle": layer(["textIndex": i, "range": range]),
        "text.editString": layer(["textIndex": i, "replacing": range, "with": s]),
        "text.setParagraph": layer(["textIndex": i, "paragraph": .optional(probe(ParagraphStyle.self))]),
        "text.setOnPath": layer(["textIndex": i, "onPath": .optional(probe(TextOnPath.self))]),
        "colorKey.set": layer(["target": target, "frame": i, "value": probe(FlareCore.Color.self),
                               "easing": FlareCore.Easing.paramSchema]),
        "colorKey.remove": layer(["target": target, "frame": i]),
        "colorKey.move": layer(["target": target, "frames": .array(of: i), "by": i]),
        "shapeKey.set": layer(["shape": i, "frame": i, "path": probe(FlareCore.Path.self),
                               "easing": FlareCore.Easing.paramSchema]),
        "shapeKey.remove": layer(["shape": i, "frame": i]),
        "mask.add": layer(["mask": probe(LayerMask.self), "index": .optional(i)]),
        "mask.set": layer(["index": i, "mask": probe(LayerMask.self)]), "mask.remove": layer(["index": i]),
        "mask.move": layer(["from": i, "to": i]), "mask.setMatte": layer(["matte": .optional(probe(TrackMatte.self))]),
    ]
}()

/// Exactly one of `cases`, each a closed object. `properties` repeats the first case's so the probe's sample (an
/// object of every listed property) decodes as that case; the kernel has no builder for `oneOf`, so it is set here.
func oneOf(_ cases: [ParamSchema]) -> ParamSchema {
    var schema = ParamSchema.none, first: JSONValue = .object([:])
    if case .object(let fields)? = cases.first?.json, let properties = fields["properties"] { first = properties }
    schema.json = .object(["type": .string("object"), "properties": first, "oneOf": .array(cases.map(\.json))])
    return schema
}

/// A one-key object, `{key: body}`: how Swift encodes an enum case with associated values.
func tagged(_ key: String, _ body: ParamSchema = .none) -> ParamSchema { .object([key: body], required: [key]) }

private let pointSchema = ParamSchema.object(["x": .number(), "y": .number()], required: ["x", "y"])

extension FlareCore.Easing: CommandSchemaProviding {
    public static var paramSchema: ParamSchema {
        let n = ParamSchema.number()
        return oneOf([tagged("linear"), tagged("cubicBezier", .object(["x1": n, "y1": n, "x2": n, "y2": n],
                                                                      required: ["x1", "y1", "x2", "y2"])), tagged("hold")])
    }
}

extension Fill: CommandSchemaProviding {
    public static var paramSchema: ParamSchema {
        let color = SchemaProbe.schema(of: FlareCore.Color.self)
        let stops = ParamSchema.array(of: .object(["offset": .number(), "color": color], required: ["offset", "color"]))
        return oneOf([color,
                      .object(["type": .string(oneOf: ["linear"]), "stops": stops, "start": pointSchema, "end": pointSchema],
                              required: ["type", "stops", "start", "end"]),
                      .object(["type": .string(oneOf: ["radial"]), "stops": stops, "center": pointSchema, "radius": .number()],
                              required: ["type", "stops", "center", "radius"])])
    }
}

extension PathElement: CommandSchemaProviding {
    public static var paramSchema: ParamSchema {
        let to = ParamSchema.object(["to": pointSchema], required: ["to"])
        return oneOf([tagged("move", to), tagged("line", to),
                      tagged("quad", .object(["control": pointSchema, "to": pointSchema], required: ["control", "to"])),
                      tagged("cubic", .object(["control1": pointSchema, "control2": pointSchema, "to": pointSchema],
                                              required: ["control1", "control2", "to"])), tagged("close")])
    }
}

extension TrackTarget: CommandSchemaProviding {
    public static var paramSchema: ParamSchema {
        let shape = ParamSchema.object(["shape": .integer()], required: ["shape"])
        return oneOf([tagged("fill", shape), tagged("stroke", shape),
                      tagged("text", .object(["index": .integer()], required: ["index"]))])
    }
}

extension InputValue: CommandSchemaProviding {
    public static var paramSchema: ParamSchema { oneOf([tagged("bool", .boolean), tagged("number", .number())]) }
}

extension Guide.Axis: CommandSchemaProviding {
    public static var paramSchema: ParamSchema { .string(oneOf: ["horizontal", "vertical"]) }
}
extension Instance.LoopMode: CommandSchemaProviding {
    public static var paramSchema: ParamSchema { .string(oneOf: ["loop", "playOnce", "singleFrame"]) }
}
extension Stroke.Join: CommandSchemaProviding {
    public static var paramSchema: ParamSchema { .string(oneOf: allCases.map(\.rawValue)) }
}
extension Stroke.Cap: CommandSchemaProviding {
    public static var paramSchema: ParamSchema { .string(oneOf: allCases.map(\.rawValue)) }
}
extension ConditionOp: CommandSchemaProviding {
    public static var paramSchema: ParamSchema { .string(oneOf: ["==", "<", ">"]) }
}
extension TextAlignment: CommandSchemaProviding {
    public static var paramSchema: ParamSchema { .string(oneOf: ["leading", "center", "trailing", "justified"]) }
}
extension MaskMode: CommandSchemaProviding {
    public static var paramSchema: ParamSchema { .string(oneOf: ["add", "subtract", "intersect", "difference"]) }
}
extension MatteKind: CommandSchemaProviding {
    public static var paramSchema: ParamSchema { .string(oneOf: ["alpha", "alphaInverted", "luma", "lumaInverted"]) }
}
