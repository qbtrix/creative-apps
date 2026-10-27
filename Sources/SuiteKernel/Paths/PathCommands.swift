// PathCommands.swift (pen-paths PN-1 specs with real ids, schemas and availability, PN-7 bodies): the twelve path
// commands each app adds with `+ PathCommands.specs(<X>Workspace.self)`, and its gestures. Each edit applies one
// `PenRules` or `AnchorEdit` rule and calls `addPath` or `setPath` exactly once with its title, passing a drag token
// through so the target's `History` folds a drag into one undo step; a bad ref or a refused rule fails before that call.
// One coordinate rule: every param and `path.read`'s result is in document space, and an edit maps it into the path's
// own space through `PathInEdit.toDocument` once, here (a delta through its linear part only), so the UI, the CLI and
// the MCP server land a point in the same place on a scaled or turned layer. A layer scaled to nothing refuses edits.
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
    // Each command's params, named for it (`Empty` for the ones that take none).
    struct Empty: Codable, Sendable {}
    struct AnchorParams: Codable, Sendable { var x, y: Double; var inX, inY, outX, outY: Double?; var kind: AnchorKind }
    struct ContourParams: Codable, Sendable { var closed: Bool; var anchors: [AnchorParams] }
    struct DrawParams: Codable, Sendable { var contours: [ContourParams] }
    struct PenParams: Codable, Sendable { var x, y: Double; var outX, outY: Double? }
    struct RectParams: Codable, Sendable { var x, y, width, height: Double }
    struct SelectParams: Codable, Sendable { var anchors: [[Int]]?; var rect: RectParams?; var extend, all: Bool? }
    struct MoveParams: Codable, Sendable { var dx, dy: Double; var drag: String? }
    struct HandleParams: Codable, Sendable { var contour, index: Int; var end: HandleEnd; var x, y: Double; var breaking: Bool?; var drag: String? }
    struct PointParams: Codable, Sendable { var x, y: Double }
    struct KindParams: Codable, Sendable { var kind: AnchorKind }

    /// Why a command can't run: nothing to read or edit, no draft, too few anchors, no point selected.
    static let noPathHelp = "Select a path or start one with the Pen.", editHelp = "Select a path to edit its points."
    static let noDraftHelp = "Click with the Pen to start a path.", closeHelp = "Click a third point to close the path.", pointHelp = "Select a point first."
    /// Why a run refuses its params: off the path, no handle to drag, too few or non-finite points, a ref past the path.
    static let offPathHelp = "Click on the path to add a point.", noHandleHelp = "That point has no handle there; hold Option to drag one out."
    static let fewHelp = "A path needs at least two points.", finiteHelp = "Every coordinate must be a finite number."
    static let flatHelp = "This path's layer is scaled to nothing; give it a size to edit its points."
    /// How near the path, in document points, `path.anchor-insert` takes a click.
    static let insertReach = 6.0
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
        [spec("path.read", "Read Path", .query, "Reads the path in edit, or the Pen's draft, and the selected points.", Empty.self,
              result: .object(["contours": contours, "selected": .array(of: ref)], required: ["contours", "selected"]),
              availability: { readable($0) }) { t, _ in try read(t) },
         spec("path.draw", "Add Path", .edit, "Adds a path of the given contours as a new layer, as path.read writes them.", DrawParams.self,
              .object(["contours": contours], required: ["contours"]),
              example: .object(["contours": .array([.object(["closed": .bool(false), "anchors": .array([corner(0, 0), corner(100, 50)])])])]),
              availability: { help($0.pathHelp) }) { t, p in try add(&t, try drawn(p)) },
         spec("path.pen-add", "Pen Point", .view, "Adds a point to the Pen's draft; a drag gives it an out handle.", PenParams.self,
              .object(["x": n, "y": n, "outX": opt, "outY": opt], required: ["x", "y", "outX", "outY"]), example: point,
              availability: { help($0.pathHelp) }) { t, p in
                  t.penDraft = PenRules.add(Point(x: p.x, y: p.y), handleOut: at(p.outX, p.outY), to: t.penDraft, scale: t.penDraft?.scale ?? 1)
                  return .object([:])
              },
         spec("path.close", "Add Path", .edit, "Closes the Pen's draft on its first point and adds it as a path.", Empty.self,
              availability: { closable($0) }) { t, _ in
                  let path = try PenRules.path(PenRules.closed(try draft(t)))
                  return try add(&t, path)
              },
         spec("path.finish", "Add Path", .edit, "Ends the Pen's draft as an open path.", Empty.self,
              availability: { help(PenRules.finishHelp($0.penDraft) ?? $0.pathHelp) }) { t, _ in
                  let path = try PenRules.path(try draft(t))
                  return try add(&t, path)
              },
         spec("path.cancel", "Cancel Path", .view, "Drops the Pen's draft.", Empty.self,
              availability: { help($0.penDraft == nil ? noDraftHelp : nil) }) { t, _ in t.penDraft = nil; return .object([:]) },
         spec("path.anchor-select", "Select Points", .view, "Selects points by ref, in a rect, or all; extend adds to the selection.", SelectParams.self,
              .object(["anchors": .optional(.array(of: ref)), "rect": .optional(rect), "extend": .optional(.boolean), "all": .optional(.boolean)],
                      required: ["anchors", "rect", "extend", "all"]), example: .object(["all": .bool(true)]),
              availability: { editable($0) }) { t, p in try select(&t, p) },
         spec("path.anchor-move", "Move Points", .edit, "Moves the selected points and their handles; one drag token is one undo step.", MoveParams.self,
              .object(["dx": n, "dy": n, "drag": drag], required: ["dx", "dy", "drag"]), example: .object(["dx": .number(10), "dy": .number(0)]),
              availability: { selected($0) }) { t, p in
                  try edit(&t, "Move Points", drag: p.drag) { e, refs in
                      let back = try local(e, "path.anchor-move"), o = back.apply(Point(x: 0, y: 0)), d = back.apply(Point(x: p.dx, y: p.dy))
                      return AnchorEdit.moved(e.path, refs, dx: d.x - o.x, dy: d.y - o.y)
                  }
              },
         spec("path.handle-move", "Move Handle", .edit, "Moves one handle of a point; a smooth partner follows unless breaking.", HandleParams.self,
              .object(["contour": index, "index": index, "end": .string("in or out.", oneOf: ["in", "out"]), "x": n, "y": n, "breaking": .optional(.boolean),
                       "drag": drag], required: ["contour", "index", "end", "x", "y", "breaking", "drag"]),
              example: .object(["contour": .number(0), "index": .number(1), "end": .string("out"), "x": .number(120), "y": .number(20)]),
              availability: { editable($0) }) { t, p in try edit(&t, "Move Handle", drag: p.drag) { e, _ in try handled(e, p) } },
         spec("path.anchor-insert", "Add Point", .edit, "Adds a point on the path nearest (x, y); off the path it refuses.", PointParams.self,
              .object(["x": n, "y": n], required: ["x", "y"]), example: point, availability: { editable($0) }) { t, p in try insert(&t, p) },
         spec("path.anchor-remove", "Delete Points", .edit, "Deletes the selected points.", Empty.self, availability: { selected($0) }) { t, _ in
             let result = try edit(&t, "Delete Points") { try AnchorEdit.removing($0.path, $1) }
             t.anchorSelection.clear()
             return result
         },
         spec("path.anchor-convert", "Convert Points", .edit, "Makes the selected points corner, smooth or symmetric.", KindParams.self,
              .object(["kind": kind], required: ["kind"]), example: .object(["kind": .string("smooth")]),
              availability: { selected($0) }) { t, p in try edit(&t, "Convert Points") { try AnchorEdit.converting($0.path, $1, to: p.kind) } }]
    }
    /// One spec decoding its params as `P` before `run`.
    static func spec<T: PathEditTarget, P: Decodable & Sendable>(_ id: String, _ title: String, _ kind: CommandKind, _ summary: String, _ params: P.Type,
                                                                 _ schema: ParamSchema = .none, result: ParamSchema = .none, example: JSONValue = .object([:]),
                                                                 availability: @escaping @Sendable (T) -> Availability,
                                                                 run: @escaping @Sendable (inout T, P) throws -> JSONValue) -> CommandSpec<T> {
        .typed(id, title: title, summary: summary, kind: kind, params: P.self, schema: schema, result: result, example: example,
               availability: availability, run: run)
    }
    // Availability: unavailable with `why`; then after `pathHelp`, a path or draft, a draft of three, a path, a point.
    static func help(_ why: String?) -> Availability { why.map(Availability.unavailable) ?? .available }
    static func readable<T: PathEditTarget>(_ t: T) -> Availability { help(t.pathInEdit == nil && t.penDraft == nil ? noPathHelp : nil) }
    static func closable<T: PathEditTarget>(_ t: T) -> Availability { help(t.pathHelp ?? (t.penDraft.map { distinct($0) < 3 ? closeHelp : nil } ?? noDraftHelp)) }
    static func editable<T: PathEditTarget>(_ t: T) -> Availability { help(t.pathHelp ?? (t.pathInEdit == nil ? editHelp : nil)) }
    static func selected<T: PathEditTarget>(_ t: T) -> Availability { editable(t) == .available && t.anchorSelection.set.isEmpty ? .unavailable(pointHelp) : editable(t) }
    /// The draft's anchors `anchorTolerance` apart on screen, `PenRules.closes`'s count.
    static func distinct(_ d: PenDraft) -> Int { PenRules.distinct(d.contour.anchors.map(\.point), PenRules.scaled(PenRules.anchorTolerance, d.scale)) }

    static func refused(_ id: String, _ why: String) -> CatalogError { .unavailable(id: id, why: why) }
    static func at(_ x: Double?, _ y: Double?) -> Point? { x.flatMap { x in y.map { Point(x: x, y: $0) } } }
    static func draft<T: PathEditTarget>(_ t: T) throws -> PenDraft {
        guard let d = t.penDraft else { throw refused("path", noDraftHelp) }
        return d
    }
    /// Adds `path` as one "Add Path" step; the draft goes and no point is selected.
    static func add<T: PathEditTarget>(_ t: inout T, _ path: VectorPath) throws -> JSONValue {
        _ = try t.addPath(path, name: "Add Path")
        t.penDraft = nil
        t.anchorSelection.clear()
        return .object([:])
    }
    /// The path in edit after `change` (given it and the selected refs), set back once as the step `title`, under `drag`
    /// when there is one. No path in edit, or a `change` that throws, fails before anything is recorded.
    static func edit<T: PathEditTarget>(_ t: inout T, _ title: String, drag: String? = nil,
                                        _ change: (PathInEdit, Set<AnchorRef>) throws -> VectorPath) throws -> JSONValue {
        guard let e = t.pathInEdit else { throw refused("path", editHelp) }
        let path = try change(e, t.anchorSelection.set)
        try t.setPath(path, name: title, drag: drag)
        return .object([:])
    }
    /// `path.read`'s result: the path in edit's contours as measured, in document space, or the draft's, and the selected refs.
    static func read<T: PathEditTarget>(_ t: T) throws -> JSONValue {
        guard let contours = t.pathInEdit.map({ $0.path.transformed(by: $0.toDocument).contours }) ?? t.penDraft.map({ [$0.contour] }) else {
            throw refused("path.read", noPathHelp)
        }
        let json = contours.map { c in JSONValue.object(["closed": .bool(c.closed), "anchors": .array(c.anchors.map { a in
            PathIntent.o(["x": .number(a.point.x), "y": .number(a.point.y), "inX": PathIntent.n(a.handleIn?.x), "inY": PathIntent.n(a.handleIn?.y),
                          "outX": PathIntent.n(a.handleOut?.x), "outY": PathIntent.n(a.handleOut?.y), "kind": .string(a.kind.rawValue)])
        })]) }
        return .object(["contours": .array(json), "selected": .array(t.anchorSelection.ordered.map(PathIntent.ref))])
    }
    /// `path.draw`'s path; fewer than two anchors or a non-finite coordinate fails.
    static func drawn(_ p: DrawParams) throws -> VectorPath {
        let contours = p.contours.map { c in VectorContour(anchors: c.anchors.map {
            VectorAnchor(point: Point(x: $0.x, y: $0.y), handleIn: at($0.inX, $0.inY), handleOut: at($0.outX, $0.outY), kind: $0.kind)
        }, closed: c.closed) }
        let anchors = contours.flatMap(\.anchors)
        guard anchors.count >= 2 else { throw refused("path.draw", fewHelp) }
        guard anchors.allSatisfy({ [$0.point, $0.handleIn, $0.handleOut].allSatisfy { $0?.isFinite ?? true } }) else { throw refused("path.draw", finiteHelp) }
        return VectorPath(contours: contours)
    }
    /// The selection `path.anchor-select` makes: every anchor, or the refs the path has plus those in the rect, added to
    /// the selection when `extend`.
    static func select<T: PathEditTarget>(_ t: inout T, _ p: SelectParams) throws -> JSONValue {
        guard let e = t.pathInEdit else { throw refused("path.anchor-select", editHelp) }
        let every = e.path.contours.enumerated().flatMap { c in c.element.anchors.indices.map { AnchorRef(contour: c.offset, index: $0) } }
        var picked = p.all == true ? every : (p.anchors ?? []).compactMap { $0.count == 2 ? AnchorRef(contour: $0[0], index: $0[1]) : nil }.filter(Set(every).contains)
        if p.all != true, let r = p.rect {
            picked += AnchorIndex(e.path, toDocument: e.toDocument).inside(Rect(minX: min(r.x, r.x + r.width), minY: min(r.y, r.y + r.height),
                                                                                  maxX: max(r.x, r.x + r.width), maxY: max(r.y, r.y + r.height)))
        }
        t.anchorSelection.replace(p.extend == true ? t.anchorSelection.ordered + picked : picked)
        return .object([:])
    }
    /// Document space into `e`'s path space; a layer scaled to nothing refuses `id`.
    static func local(_ e: PathInEdit, _ id: String) throws -> Matrix {
        guard let back = try? e.toDocument.inverted() else { throw refused(id, flatHelp) }
        return back
    }
    /// The path in edit with `p`'s handle moved to its document point; a ref past the path, or a missing handle
    /// without `breaking`, fails.
    static func handled(_ e: PathInEdit, _ p: HandleParams) throws -> VectorPath {
        let ref = AnchorRef(contour: p.contour, index: p.index), path = e.path, contours = path.contours
        guard contours.indices.contains(ref.contour), contours[ref.contour].anchors.indices.contains(ref.index) else {
            throw refused("path.handle-move", "The path has no point \(ref.index) in contour \(ref.contour).")
        }
        let a = contours[ref.contour].anchors[ref.index], breaking = p.breaking ?? false
        guard breaking || (p.end == .handleIn ? a.handleIn : a.handleOut) != nil else { throw refused("path.handle-move", noHandleHelp) }
        return AnchorEdit.movingHandle(path, ref, p.end, to: try local(e, "path.handle-move").apply(Point(x: p.x, y: p.y)), breaking: breaking)
    }
    /// `path.anchor-insert`: a point where the path in edit passes within `insertReach` of (x, y), in document space,
    /// then selected alone; off the path it refuses.
    static func insert<T: PathEditTarget>(_ t: inout T, _ p: PointParams) throws -> JSONValue {
        var added: AnchorRef?
        let result = try edit(&t, "Add Point") { e, _ in
            guard let location = try e.path.transformed(by: e.toDocument).nearest(to: Point(x: p.x, y: p.y), tolerance: insertReach / 8),
                  location.distance <= insertReach else { throw refused("path.anchor-insert", offPathHelp) }
            let inserted = try AnchorEdit.inserting(e.path, at: location)
            added = inserted.ref
            return inserted.path
        }
        if let added { t.anchorSelection.replace([added]) }
        return result
    }
}
