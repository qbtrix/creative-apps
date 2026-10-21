// PathCommands.swift (pen-paths PN-1 specs with real ids, schemas and availability, runs throwing `PenRules.notBuilt`;
// PN-7 bodies): the twelve path commands each app adds with `+ PathCommands.specs(<X>Workspace.self)`, and its gestures.
/// One gesture of the Pen or the point editor; the app runs its `command` through its catalog.
public enum PathIntent: Hashable, Sendable {
    case penAdd(Point, handleOut: Point?), close, finish, cancel
    case select(anchors: [AnchorRef]?, rect: Rect?, extend: Bool), selectAll
    case move(dx: Double, dy: Double, drag: String?), handle(AnchorRef, HandleEnd, to: Point, breaking: Bool, drag: String?)
    case insert(Point), remove, convert(AnchorKind)
    public var command: (id: String, params: JSONValue) {
        switch self {
        case .penAdd(let p, let out): ("path.pen-add", Self.o(["x": .number(p.x), "y": .number(p.y), "outX": Self.n(out?.x), "outY": Self.n(out?.y)]))
        case .close, .finish, .cancel, .remove: (self == .remove ? "path.anchor-remove" : "path.\(self)", Self.o([:]))
        case .select(let anchors, let r, let extend): ("path.anchor-select", Self.o(["anchors": anchors.map { .array($0.map(Self.ref)) }, "extend": .bool(extend),
            "rect": r.map { Self.o(["x": .number($0.minX), "y": .number($0.minY), "width": .number($0.maxX - $0.minX), "height": .number($0.maxY - $0.minY)]) }]))
        case .selectAll: ("path.anchor-select", Self.o(["all": .bool(true)]))
        case .move(let dx, let dy, let drag): ("path.anchor-move", Self.o(["dx": .number(dx), "dy": .number(dy), "drag": drag.map(JSONValue.string)]))
        case .handle(let r, let end, let to, let breaking, let drag): ("path.handle-move", Self.o(["contour": Self.n(Double(r.contour)),
            "index": Self.n(Double(r.index)), "end": .string(end.rawValue), "x": .number(to.x), "y": .number(to.y), "breaking": .bool(breaking), "drag": drag.map(JSONValue.string)]))
        case .insert(let p): ("path.anchor-insert", Self.o(["x": .number(p.x), "y": .number(p.y)]))
        case .convert(let kind): ("path.anchor-convert", Self.o(["kind": .string(kind.rawValue)]))
        }
    }
    /// An anchor ref as `[contour, index]`; an object of the fields that are set; a number when there is one.
    static func ref(_ r: AnchorRef) -> JSONValue { .array([.number(Double(r.contour)), .number(Double(r.index))]) }
    static func o(_ fields: [String: JSONValue?]) -> JSONValue { .object(fields.compactMapValues { $0 }) }
    static func n(_ v: Double?) -> JSONValue? { v.map(JSONValue.number) }
}
public enum PathCommands {
    /// Why a command can't run: nothing to read or edit, no draft, too few anchors, no point selected.
    static let noPathHelp = "Select a path or start one with the Pen.", editHelp = "Select a path to edit its points."
    static let noDraftHelp = "Click with the Pen to start a path.", closeHelp = "Click a third point to close the path.", pointHelp = "Select a point first."
    static let n = ParamSchema.number(), opt = ParamSchema.optional(.number()), index = ParamSchema.integer(minimum: 0)
    static let kind = ParamSchema.string("corner, smooth or symmetric.", oneOf: ["corner", "smooth", "symmetric"])
    static let drag = ParamSchema.optional(.string("A drag's token; edits under one token are one undo step.", maxLength: 64))
    static let ref = ParamSchema.array(of: index, minItems: 2, maxItems: 2)
    static let anchor = ParamSchema.object(["x": n, "y": n, "inX": opt, "inY": opt, "outX": opt, "outY": opt, "kind": kind],
                                           required: ["x", "y", "inX", "inY", "outX", "outY", "kind"])
    static let contours = ParamSchema.array(of: .object(["closed": .boolean, "anchors": .array(of: anchor, minItems: 1)], required: ["closed", "anchors"]), minItems: 1)
    static let rect = ParamSchema.object(["x": n, "y": n, "width": n, "height": n], required: ["x", "y", "width", "height"])
    static let point = JSONValue.object(["x": .number(150), "y": .number(0)])
    static func corner(_ x: Double, _ y: Double) -> JSONValue { .object(["x": .number(x), "y": .number(y), "kind": .string("corner")]) }
    /// The twelve path commands on `target`, in menu order: a query, the Pen's presses and views, then one-step edits.
    public static func specs<T: PathEditTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [spec("path.read", "Read Path", .query, "Reads the path in edit, or the Pen's draft, and the selected points.",
              result: .object(["contours": contours, "selected": .array(of: ref)], required: ["contours", "selected"])) { readable($0) },
         spec("path.draw", "Add Path", .edit, "Adds a path of the given contours as a new layer, as path.read writes them.",
              .object(["contours": contours], required: ["contours"]),
              example: .object(["contours": .array([.object(["closed": .bool(false), "anchors": .array([corner(0, 0), corner(100, 50)])])])])) { help($0.pathHelp) },
         spec("path.pen-add", "Pen Point", .view, "Adds a point to the Pen's draft; a drag gives it an out handle.",
              .object(["x": n, "y": n, "outX": opt, "outY": opt], required: ["x", "y", "outX", "outY"]), example: point) { help($0.pathHelp) },
         spec("path.close", "Add Path", .edit, "Closes the Pen's draft on its first point and adds it as a path.") { closable($0) },
         spec("path.finish", "Add Path", .edit, "Ends the Pen's draft as an open path.") { help(PenRules.finishHelp($0.penDraft) ?? $0.pathHelp) },
         spec("path.cancel", "Cancel Path", .view, "Drops the Pen's draft.") { help($0.penDraft == nil ? noDraftHelp : nil) },
         spec("path.anchor-select", "Select Points", .view, "Selects points by ref, in a rect, or all; extend adds to the selection.",
              .object(["anchors": .optional(.array(of: ref)), "rect": .optional(rect), "extend": .optional(.boolean), "all": .optional(.boolean)],
                      required: ["anchors", "rect", "extend", "all"]), example: .object(["all": .bool(true)])) { editable($0) },
         spec("path.anchor-move", "Move Points", .edit, "Moves the selected points and their handles; one drag token is one undo step.",
              .object(["dx": n, "dy": n, "drag": drag], required: ["dx", "dy", "drag"]), example: .object(["dx": .number(10), "dy": .number(0)])) { selected($0) },
         spec("path.handle-move", "Move Handle", .edit, "Moves one handle of a point; a smooth partner follows unless breaking.",
              .object(["contour": index, "index": index, "end": .string("in or out.", oneOf: ["in", "out"]), "x": n, "y": n, "breaking": .optional(.boolean),
                       "drag": drag], required: ["contour", "index", "end", "x", "y", "breaking", "drag"]),
              example: .object(["contour": .number(0), "index": .number(1), "end": .string("out"), "x": .number(120), "y": .number(20)])) { editable($0) },
         spec("path.anchor-insert", "Add Point", .edit, "Adds a point on the path nearest (x, y); off the path it refuses.",
              .object(["x": n, "y": n], required: ["x", "y"]), example: point) { editable($0) },
         spec("path.anchor-remove", "Delete Points", .edit, "Deletes the selected points.") { selected($0) },
         spec("path.anchor-convert", "Convert Points", .edit, "Makes the selected points corner, smooth or symmetric.",
              .object(["kind": kind], required: ["kind"]), example: .object(["kind": .string("smooth")])) { selected($0) }]
    }
    /// One spec whose run refuses with `PenRules.notBuilt` until PN-7; PN-7 decodes its params.
    static func spec<T: PathEditTarget>(_ id: String, _ title: String, _ kind: CommandKind, _ summary: String, _ schema: ParamSchema = .none,
                                        result: ParamSchema = .none, example: JSONValue = .object([:]),
                                        availability: @escaping @Sendable (T) -> Availability) -> CommandSpec<T> {
        .typed(id, title: title, summary: summary, kind: kind, params: JSONValue.self, schema: schema, result: result, example: example,
               availability: availability) { _, _ -> JSONValue in throw PenRules.notBuilt }
    }
    // Availability: unavailable with `why`; then after `pathHelp`, a path or draft, a draft of three, a path, a point.
    static func help(_ why: String?) -> Availability { why.map(Availability.unavailable) ?? .available }
    static func readable<T: PathEditTarget>(_ t: T) -> Availability { help(t.pathInEdit == nil && t.penDraft == nil ? noPathHelp : nil) }
    static func closable<T: PathEditTarget>(_ t: T) -> Availability { help(t.pathHelp ?? (t.penDraft.map { $0.contour.anchors.count < 3 ? closeHelp : nil } ?? noDraftHelp)) }
    static func editable<T: PathEditTarget>(_ t: T) -> Availability { help(t.pathHelp ?? (t.pathInEdit == nil ? editHelp : nil)) }
    static func selected<T: PathEditTarget>(_ t: T) -> Availability { editable(t) == .available && t.anchorSelection.set.isEmpty ? .unavailable(pointHelp) : editable(t) }
}
