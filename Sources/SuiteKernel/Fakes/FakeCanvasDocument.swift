// FakeCanvasDocument.swift (command-catalog CC-2): a Linux headless document of named rects, with the six
// commands the catalog's tests, the gallery page, the afterglow CLI and the MCP server drive before any app adopts;
// file-flow SF-9 adds the five file-flow commands over fixed readers, so RJ-X43 runs `file.drop` on the CLI;
// gradient-fill GF-9 gives each rect an optional fill and lists the eight fill commands, so RJ-X30 runs on the CLI;
// autosave-history AH-9 lists `history.read` and `history.jump` over its one History, so RJ-X31 runs on the CLI;
// transform-tools TT-8 gives each rect a turn and mirrors and lists the six transform commands, so RJ-X32 runs on the CLI;
// stroke-style SS-8 gives each rect an optional stroke and lists the nine stroke commands, so RJ-X35 runs on the CLI;
// eyedropper EY-8 reads the topmost rect's fill at a point and lists `color.sample`, so RJ-X33 runs on the CLI;
// placed-images PL-9 lets a rect show a placed picture, saves each file's bytes once and lists the five place
// commands, so RJ-X36 runs on the CLI.
// shape-tools SH-8 gives each rect an optional shape spec and lists `shape.draw` and `tool.shape`, so RJ-X34 runs on
// the CLI.
// export-pack XP-9 exports PNG and JPEG at a size read by `SuiteExportOptions(json:)` through ExportRules, so RJ-X42
// runs on the CLI.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One named rect on the fake canvas; a locked one refuses move, remove, a fill, a stroke, a transform and a picture.
public struct FakeRect: Codable, Hashable, Sendable {
    /// The rect's id, its name ("Rect 1"), its frame and whether it is locked.
    public var id: Int, name: String, x, y, w, h: Double, locked: Bool
    /// The rect's fill, its points in the rect's own box (0, 0, w, h); nil reads as solid black and is left out of
    /// the JSON, so a rect with no fill saves what it did before fills.
    public var fill: Fill?
    /// The rect's outline, dash and trim included; nil draws none and is left out of the JSON, as `fill` is.
    public var stroke: VectorStroke?
    /// The rect's clockwise turn in degrees about its centre and its mirrors; at 0 and false they are left out of
    /// the JSON, so a rect never turned saves what it did before turns.
    public var degrees = 0.0, flipX = false, flipY = false
    /// The picture the rect shows, by cover in its frame; nil is left out of the JSON, so a rect with no picture
    /// saves what it did before pictures.
    public var placed: PlacedImage?
    /// The shape `shape.draw` drew in the rect's box; nil is a plain rect and is left out of the JSON, as `fill` is.
    public var shape: ShapeSpec?
    public init(id: Int, name: String, x: Double, y: Double, w: Double, h: Double, locked: Bool = false, fill: Fill? = nil,
                stroke: VectorStroke? = nil, shape: ShapeSpec? = nil) {
        (self.id, self.name, self.x, self.y, self.w, self.h, self.locked, self.fill, self.stroke) = (id, name, x, y, w, h, locked, fill, stroke)
        self.shape = shape
    }
    private enum CodingKeys: String, CodingKey { case id, name, x, y, w, h, locked, fill, stroke, degrees, flipX, flipY, placed, shape }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(Int.self, forKey: .id), name: try c.decode(String.self, forKey: .name),
                  x: try c.decode(Double.self, forKey: .x), y: try c.decode(Double.self, forKey: .y),
                  w: try c.decode(Double.self, forKey: .w), h: try c.decode(Double.self, forKey: .h),
                  locked: try c.decode(Bool.self, forKey: .locked), fill: try c.decodeIfPresent(Fill.self, forKey: .fill),
                  stroke: try c.decodeIfPresent(VectorStroke.self, forKey: .stroke), shape: try c.decodeIfPresent(ShapeSpec.self, forKey: .shape))
        degrees = try c.decodeIfPresent(Double.self, forKey: .degrees) ?? 0
        (flipX, flipY) = (try c.decodeIfPresent(Bool.self, forKey: .flipX) ?? false, try c.decodeIfPresent(Bool.self, forKey: .flipY) ?? false)
        placed = try c.decodeIfPresent(PlacedImage.self, forKey: .placed)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encode(x, forKey: .x); try c.encode(y, forKey: .y)
        try c.encode(w, forKey: .w); try c.encode(h, forKey: .h); try c.encode(locked, forKey: .locked)
        try c.encodeIfPresent(fill, forKey: .fill)
        try c.encodeIfPresent(stroke, forKey: .stroke)
        if degrees != 0 { try c.encode(degrees, forKey: .degrees) }
        if flipX { try c.encode(flipX, forKey: .flipX) }
        if flipY { try c.encode(flipY, forKey: .flipY) }
        try c.encodeIfPresent(placed, forKey: .placed)
        try c.encodeIfPresent(shape, forKey: .shape)
    }
    /// The box the rect's fill points are in: its own frame from the origin.
    public var fillBox: Rect { Rect(minX: 0, minY: 0, maxX: w, maxY: h) }
    /// The rect's frame on the canvas.
    public var frame: Rect { Rect(minX: x, minY: y, maxX: x + w, maxY: y + h) }
}

/// A headless document of named rects, a selection and one history: the catalog's fake app ("fake").
public struct FakeCanvasDocument: HeadlessDocument {
    /// `rect.add`'s params: the frame and an optional name.
    public struct AddRect: Codable, Sendable, CommandSchemaProviding {
        public var x, y, w, h: Double; public var name: String?
        public init(x: Double, y: Double, w: Double, h: Double, name: String? = nil) { (self.x, self.y, self.w, self.h, self.name) = (x, y, w, h, name) }
        public static let paramSchema = ParamSchema.object(
            ["x": .number("Left edge."), "y": .number("Top edge."), "w": .number("Width.", minimum: 1),
             "h": .number("Height.", minimum: 1), "name": .optional(.string("The rect's name.", maxLength: 64))],
            required: ["x", "y", "w", "h", "name"])
    }
    /// `rect.move`'s params: the offset, and the drag whose moves fold into one undo step.
    public struct MoveRect: Codable, Sendable, CommandSchemaProviding {
        public var dx, dy: Double; public var drag: String?
        public init(dx: Double, dy: Double, drag: String? = nil) { (self.dx, self.dy, self.drag) = (dx, dy, drag) }
        public static let paramSchema = ParamSchema.object(
            ["dx": .number("Horizontal offset."), "dy": .number("Vertical offset."),
             "drag": .optional(.string("A drag's token; moves under one token are one undo step.", maxLength: 64))],
            required: ["dx", "dy", "drag"])
    }
    /// `rect.select`'s params: the rect to select.
    public struct SelectRect: Codable, Sendable, CommandSchemaProviding {
        public var id: Int
        public init(id: Int) { self.id = id }
        public static let paramSchema = ParamSchema.object(["id": .integer("The rect's id.", minimum: 1)], required: ["id"])
    }
    /// No params.
    public struct NoParams: Codable, Sendable, CommandSchemaProviding { public static let paramSchema = ParamSchema.none }

    /// The rects back to front, the selected rect's id, and the history whose steps hold the rects to go back to.
    public private(set) var rects: [FakeRect], selection: Int?, history = History<[FakeRect]>()
    /// The fake's recent files, newest first; Clear Menu empties them.
    public private(set) var recents: [RecentFileEntry]
    /// The placed files' bytes, one per file; kept past an undo for redo, pruned to what the rects show on save.
    public private(set) var assets = PlacedAssets()
    /// The shape tool's options, which `tool.shape` sets and `shape.draw` never reads; a view setting, never a step.
    public private(set) var shapeTool = ShapeSpec.defaults(.rectangle)
    public init(rects: [FakeRect] = [], selection: Int? = nil, recents: [RecentFileEntry] = []) {
        (self.rects, self.selection, self.recents) = (rects, selection, recents)
    }

    /// The document every example runs on: "Rect 1" selected and free, with a three-stop linear fill so every fill
    /// example runs on it, and "Rect 2" locked.
    public static let fixture = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 10, y: 10, w: 100, h: 60, fill: fixtureFill),
                                                           FakeRect(id: 2, name: "Rect 2", x: 140, y: 40, w: 80, h: 80, locked: true)],
                                                   selection: 1, recents: [example])
    /// The fixture's one recent file, the file-flow examples' `path:/tmp/example`.
    static let example = RecentFileEntry(fileID: "path:/tmp/example", name: "example", path: "/tmp/example", app: app,
                                         lastUsed: Date(timeIntervalSince1970: 0))
    /// Rect 1's fill: blue, white and black, left to right across its box.
    static let fixtureFill = Fill.linear(stops: [GradientStop(offset: 0, color: FillColor(r: 0, g: 0, b: 1)), GradientStop(offset: 0.5, color: .white),
                                                 GradientStop(offset: 1, color: .black)], start: Point(x: 0, y: 30), end: Point(x: 100, y: 30))
    public static let app = "fake", openExtensions = ["fake"]
    /// `json`, then each raster format FakeRaster has a writer for, by ExportFormats id.
    public static let exportFormats = ["json"] + FakeRaster.writers.map(\.format)

    /// The selected rect, nil when nothing is selected.
    public var selected: FakeRect? { rects.first { $0.id == selection } }
    /// Whether the selected rect can move or be removed, and why not.
    public var editable: Availability {
        guard let rect = selected else { return .unavailable("Select a rectangle first.") }
        return rect.locked ? .unavailable("Unlock \(rect.name) first.") : .available
    }

    /// Adds a rect, selects it and records "Add Rectangle".
    public mutating func add(_ p: AddRect) -> FakeRect {
        let id = (rects.map(\.id).max() ?? 0) + 1
        let rect = FakeRect(id: id, name: p.name ?? "Rect \(id)", x: p.x, y: p.y, w: p.w, h: p.h)
        history.record("Add Rectangle", rects)
        rects.append(rect); selection = id
        return rect
    }
    /// Moves the selected rect, recording "Move Rectangle" (one step per drag token).
    public mutating func move(_ p: MoveRect) throws(CatalogError) -> FakeRect {
        let index = try editableIndex("rect.move")
        history.record("Move Rectangle", rects, key: p.drag.map { "rect.move:\($0)" })
        rects[index].x += p.dx; rects[index].y += p.dy
        return rects[index]
    }
    /// Removes the selected rect, recording "Remove Rectangle".
    public mutating func remove() throws(CatalogError) {
        let index = try editableIndex("rect.remove")
        history.record("Remove Rectangle", rects)
        rects.remove(at: index); selection = nil
    }
    /// Selects the rect `id`; a view change, never a step.
    public mutating func select(_ id: Int) throws(CatalogError) {
        guard rects.contains(where: { $0.id == id }) else { throw .failed(id: "rect.select", message: "There is no rect \(id).") }
        selection = id; history.endRun()
    }
    /// Undoes (or, `redo`, redoes) the last step; false when there is none.
    public mutating func step(redo: Bool) -> Bool {
        var current = rects
        let swap: ([FakeRect]) -> [FakeRect] = { old in defer { current = old }; return current }
        let moved = redo ? history.redo(swap) : history.undo(swap)
        rects = current
        if !rects.contains(where: { $0.id == selection }) { selection = nil }
        return moved
    }
    /// The selected rect's index when it can change, else the refusal for `id`.
    private func editableIndex(_ id: String) throws(CatalogError) -> Int {
        if let why = editable.why { throw .unavailable(id: id, why: why) }
        guard let index = rects.firstIndex(where: { $0.id == selection }) else { throw .unavailable(id: id, why: "Select a rectangle first.") }
        return index
    }

    /// A file with pictures: the assets the rects show, by id, and the rects.
    struct Saved: Codable { var assets: [PlacedAsset]; var rects: [FakeRect] }
    /// The rects as JSON, keys sorted: the native format and the `json` export. With no picture shown it is the
    /// rects alone, as before pictures; else the rects beside each shown file's asset, once.
    public func save() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let shown = assets.pruned(keeping: Set(rects.compactMap { $0.placed?.assetID }))
        guard !shown.byID.isEmpty else { return try encoder.encode(rects) }
        return try encoder.encode(Saved(assets: shown.byID.values.sorted { $0.id < $1.id }, rects: rects))
    }
    public static func open(_ data: Data, name: String) throws -> FakeCanvasDocument {
        guard let saved = try? JSONDecoder().decode(Saved.self, from: data) else {
            return FakeCanvasDocument(rects: try JSONDecoder().decode([FakeRect].self, from: data))
        }
        var doc = FakeCanvasDocument(rects: saved.rects)
        doc.assets = PlacedAssets(saved.assets)
        return doc
    }
    public static func new(_ options: JSONValue) throws -> FakeCanvasDocument { FakeCanvasDocument() }
    /// `json` is `save()`, options unread, as before sizes; `png` and `jpeg` are a flat grey frame at the size
    /// `options` asks for (`SuiteExportOptions(json:)`), its pixels from ExportRules, which refuses a bad option.
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] {
        if format == "json" { return [ExportedFile(suggestedName: "canvas.json", format: "json", data: try save())] }
        guard let writer = FakeRaster.writers.first(where: { $0.format == format }), let spec = ExportFormats.spec(format) else {
            throw CatalogError.failed(id: "export", message: "The fake exports \(Self.exportFormats.joined(separator: ", ")), not \(format).")
        }
        let source = exportSource, pixels: (width: Int, height: Int)
        do {
            let asked = try SuiteExportOptions(json: options, defaults: SuiteExportOptions(format: format))
            pixels = try ExportRules.pixels(of: source, asked.size, evenSize: spec.needsEvenSize)
        } catch { throw CatalogError.failed(id: "export", message: String(describing: error)) }
        return [ExportedFile(suggestedName: "canvas.\(spec.fileExtension)", format: format, data: writer.encode(pixels))]
    }
    /// The artwork at 1x: the rects' frames together, whole pixels rounded up; 0 × 0 with no rects.
    var exportSource: (width: Int, height: Int) {
        let xs = rects.flatMap { [$0.x, $0.x + $0.w] }, ys = rects.flatMap { [$0.y, $0.y + $0.h] }
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { return (0, 0) }
        let whole = { (d: Double) in d.isFinite ? Int(min(max(d.rounded(.up), 0), Double(ExportRules.maxSide + 1))) : 0 }
        return (whole(x1 - x0), whole(y1 - y0))
    }
    public func summary() -> JSONValue {
        .object(["rects": .number(Double(rects.count)), "selected": selected.map { .string($0.name) } ?? .null])
    }

    /// The fake's forty-six ids: its six commands, `edit.undo` and `edit.redo`, the five file-flow commands, the
    /// eight fill commands, the two history commands, the nine stroke commands, the six transform commands,
    /// `color.sample`, the five place commands, `shape.draw` and `tool.shape`. Empty only if an id were refused.
    public static let catalog = (try? CommandCatalog<FakeCanvasDocument>(
        app: app, specs + FileFlowCommands.specs(FakeCanvasDocument.self) + GradientCommands.specs(FakeCanvasDocument.self)
            + HistoryCommands.specs(FakeCanvasDocument.self) + StrokeCommands.specs(FakeCanvasDocument.self)
            + TransformCommands.specs(FakeCanvasDocument.self) + SampleCommands.specs(FakeCanvasDocument.self)
            + PlaceCommands.specs(FakeCanvasDocument.self) + ShapeCommands.specs(FakeCanvasDocument.self),
        history: { $0.history })) ?? .empty(app: app)
    /// A rect's result schema.
    static let rectSchema = ParamSchema.object(["id": .integer(), "name": .string(), "x": .number(), "y": .number(),
                                                "w": .number(), "h": .number(), "locked": .boolean],
                                               required: ["id", "name", "x", "y", "w", "h", "locked"])
    /// The specs, in menu order.
    static let specs: [CommandSpec<FakeCanvasDocument>] = [
        .typed("rect.add", title: "Add Rectangle", summary: "Adds a rectangle with the given frame and selects it.", kind: .edit,
               params: AddRect.self, result: rectSchema, example: .object(["x": .number(10), "y": .number(20), "w": .number(30), "h": .number(40)])) { doc, p in doc.add(p) },
        .typed("rect.move", title: "Move Rectangle", summary: "Moves the selected rectangle by an offset; moves under one drag token are one undo step.",
               kind: .edit, params: MoveRect.self, result: rectSchema, example: .object(["dx": .number(5), "dy": .number(0)]),
               availability: { $0.editable }) { doc, p in try doc.move(p) },
        .typed("rect.remove", title: "Remove Rectangle", summary: "Removes the selected rectangle.", kind: .edit, params: NoParams.self,
               example: .object([:]), availability: { $0.editable }) { doc, _ in try doc.remove(); return JSONValue.object([:]) },
        .typed("rect.select", title: "Select Rectangle", summary: "Selects the rectangle with the given id.", kind: .view,
               params: SelectRect.self, example: .object(["id": .number(1)])) { doc, p in try doc.select(p.id); return JSONValue.object([:]) },
        .typed("rect.list", title: "List Rectangles", summary: "Lists every rectangle, back to front.", kind: .query, params: NoParams.self,
               result: .array(of: rectSchema), example: .object([:])) { doc, _ in doc.rects },
        .typed("doc.export-json", title: "Export JSON", summary: "Exports the rectangles as JSON text.", kind: .file, params: NoParams.self,
               result: .object(["json": .string()], required: ["json"]), example: .object([:])) { doc, _ in
            ["json": String(decoding: try doc.save(), as: UTF8.self)]
        },
        .typed("edit.undo", title: "Undo", summary: "Undoes the last edit.", kind: .view, params: NoParams.self, example: .object([:]),
               availability: { $0.history.canUndo ? .available : .unavailable("There is nothing to undo.") }) { doc, _ in doc.step(redo: false) },
        .typed("edit.redo", title: "Redo", summary: "Redoes the last undone edit.", kind: .view, params: NoParams.self, example: .object([:]),
               availability: { $0.history.canRedo ? .available : .unavailable("There is nothing to redo.") }) { doc, _ in doc.step(redo: true) },
    ]
}

/// The fake as a file-flow target: it reads `.fake`, places `.png` as a rect named after the file, and hands its
/// document to Halo. Its readers are a fixed table, never the suite's routing; nothing leaves the process.
extension FakeCanvasDocument: FileFlowTarget {
    /// The apps that read each extension the fake knows, default first.
    static let readerTable: [String: [String]] = ["fake": ["fake"], "halo": ["halo"], "png": ["photo", "design", "fake"]]
    public var appID: String { Self.app }
    public var recentFiles: [RecentFileEntry] { recents }
    public var hasDocument: Bool { true }
    public var placesExtensions: Set<String> { ["png"] }
    public var openInApps: [String] { ["halo"] }
    public var openInHelp: String? { nil }
    public func readers(ofExtension ext: String) -> [String] { Self.readerTable[ext] ?? [] }
    /// Moves the file to the top of the list; the fake has no window to open it in.
    public mutating func openRecent(_ fileID: String) throws {
        guard let index = recents.firstIndex(where: { $0.fileID == fileID }) else { return }
        recents.insert(recents.remove(at: index), at: 0)
    }
    public mutating func clearRecent() throws { recents = [] }
    /// The fake has no other app to hand to, so Open In changes nothing.
    public mutating func openIn(_ app: String) throws {}
    /// Places each `.place` file as a 100 by 100 rect named after it, all as one "Place" step; opens and hand-offs
    /// have no other window to go to in the fake, and refusals change nothing.
    public mutating func perform(_ actions: [DropAction]) throws {
        let placed = actions.compactMap { action -> String? in
            guard case .place(let path) = action else { return nil }
            return path.split(separator: "/").last.map(String.init) ?? path
        }
        guard !placed.isEmpty else { return }
        history.record("Place", rects)
        for name in placed {
            let id = (rects.map(\.id).max() ?? 0) + 1
            rects.append(FakeRect(id: id, name: name, x: 0, y: 0, w: 100, h: 100)); selection = id
        }
    }
}

/// The fake as a fill target: the selected rect's fill in its own box; a locked rect refuses with its reason.
extension FakeCanvasDocument: GradientFillTarget {
    public var fillSelection: FillSelection? { selected.map { FillSelection(fill: $0.fill ?? .solid(.black), box: $0.fillBox) } }
    public var fillHelp: String? { editable.why }
    /// Sets the selected rect's fill, mapped from `box` to its own, as the step `name` (one per `drag` token).
    public mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws {
        let index = try editableIndex("fill")
        history.record(name, rects, key: drag.map { "\(name):\($0)" })
        rects[index].fill = GradientRules.mapped(fill, from: box, to: rects[index].fillBox)
    }
}

/// The fake as a stroke target: the selected rect's stroke; a locked rect refuses with its reason, and every rect is
/// an outline, so trim always runs.
extension FakeCanvasDocument: StrokeTarget {
    public var strokeHelp: String? { editable.why }
    public var trimHelp: String? { nil }
    public var selectedStroke: VectorStroke? { selected?.stroke }
    /// Sets (nil removes) the selected rect's stroke as the step `name`; a scrub under one `drag` token is one step.
    public mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws {
        let index = try editableIndex("stroke")
        history.record(name, rects, key: drag.map { "stroke:\(name):\($0)" })
        rects[index].stroke = stroke
    }
}

/// The fake as a shape target: a drawn shape is a new rect over its box carrying its spec, selected, one step.
extension FakeCanvasDocument: ShapeTarget {
    public var shapeHelp: String? { nil }
    public mutating func pickShapeTool(_ spec: ShapeSpec) { shapeTool = spec; history.endRun() }
    /// Adds a rect named after the shape's kind ("Star 3") over `box` with `spec`, records the step `name` and
    /// selects it; returns its id.
    public mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String {
        let id = (rects.map(\.id).max() ?? 0) + 1
        history.record(name, rects)
        rects.append(FakeRect(id: id, name: "\(spec.kind.rawValue.capitalized) \(id)", x: box.minX, y: box.minY, w: box.width,
                              h: box.height, shape: spec))
        selection = id
        return String(id)
    }
}

/// The fake as the History panel's target: its one History listed from "Open", and a jump through the kernel's
/// `jumpEndingRun`, so a jump records no step and the next edit never folds into the step it landed on.
extension FakeCanvasDocument: HistoryJumping {
    public var historyListing: HistoryListing { history.listing(base: "Open") }
    public mutating func setHistoryRequest(_ name: String?) -> Bool { history.setRequest(name) }
    /// Undoes or redoes until `index` steps are applied; an index outside `0...steps.count` throws and changes nothing.
    public mutating func jumpHistory(to index: Int) throws {
        guard (0...history.steps.count).contains(index) else {
            throw CatalogError.failed(id: "history.jump", message: "There is no step \(index).")
        }
        var current = rects
        history.jumpEndingRun(to: index) { old in defer { current = old }; return current }
        rects = current
        if !rects.contains(where: { $0.id == selection }) { selection = nil }
    }
}

/// The fake as a transform target: the selected rect's box, turn and mirrors; a locked rect refuses with its reason.
extension FakeCanvasDocument: TransformTarget {
    public var transformSelection: TransformBox? {
        selected.map { TransformBox(box: Rect(minX: $0.x, minY: $0.y, maxX: $0.x + $0.w, maxY: $0.y + $0.h),
                                    degrees: $0.degrees, flipX: $0.flipX, flipY: $0.flipY) }
    }
    public var transformHelp: String? { editable.why }
    /// Sets the selected rect's frame, turn and mirrors from `t` as the step `name` (one per `drag` token).
    public mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws {
        let index = try editableIndex("transform")
        history.record(name, rects, key: drag.map { "transform.\(name):\($0)" })
        (rects[index].x, rects[index].y, rects[index].w, rects[index].h) = (t.box.minX, t.box.minY, t.box.width, t.box.height)
        (rects[index].degrees, rects[index].flipX, rects[index].flipY) = (t.degrees, t.flipX, t.flipY)
    }
}

/// The fake as an eyedropper target: the topmost rect under the point, its fill read there in the rect's own frame.
extension FakeCanvasDocument: SampleTarget {
    /// The fake can always be sampled.
    public var sampleHelp: String? { nil }
    /// The fill of the topmost rect (the last in `rects`, whatever is selected) whose turned, mirrored frame holds
    /// `point`, read at that point in the rect's own box: a gradient's colour there, a solid's colour, black for no
    /// fill; nil on empty canvas or a point that isn't finite. The fake paints flat rects, so `size` is not read.
    public func sampledColor(at point: Point, size: SampleSize) -> FillColor? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        func local(_ r: FakeRect) -> Point {
            let frame = TransformBox(box: Rect(minX: r.x, minY: r.y, maxX: r.x + r.w, maxY: r.y + r.h),
                                     degrees: r.degrees, flipX: r.flipX, flipY: r.flipY)
            let p = TransformRules.local(point, in: frame)
            return Point(x: p.x - r.x, y: p.y - r.y)
        }
        func holds(_ r: FakeRect) -> Bool {
            let p = local(r)
            return p.x >= 0 && p.x <= r.w && p.y >= 0 && p.y <= r.h
        }
        guard let top = rects.last(where: holds) else { return nil }
        let fill = top.fill ?? .solid(.black)
        return GradientRules.color(of: fill, at: Self.offset(of: fill, at: local(top)))
    }

    /// A gradient's offset at `p` in its fill box, clamped to 0...1: along the line for a linear, out from the centre
    /// for a radial; 0 for a solid, a line of no length, a radial of no radius or a value that isn't finite.
    static func offset(of fill: Fill, at p: Point) -> Double {
        let t: Double
        switch fill {
        case .solid: return 0
        case .linear(_, let start, let end):
            let (dx, dy) = (end.x - start.x, end.y - start.y)
            let length = dx * dx + dy * dy
            guard length > 0 else { return 0 }
            t = ((p.x - start.x) * dx + (p.y - start.y) * dy) / length
        case .radial(_, let center, let radius):
            guard radius > 0 else { return 0 }
            let (dx, dy) = (p.x - center.x, p.y - center.y)
            t = (dx * dx + dy * dy).squareRoot() / radius
        }
        return t.isFinite ? min(max(t, 0), 1) : 0
    }
}

/// The fake as a place target: a picture fills the selected rect by cover, or lands as a new rect at its fitted size;
/// a locked rect refuses with its reason. The fake takes PNG and SVG, reading a PNG's size from its header.
extension FakeCanvasDocument: PlacedImageTarget {
    /// The fake can always place.
    public var placeHelp: String? { nil }
    /// The fake's canvas, which a new picture fits inside: 800 × 600.
    public var placeCanvas: Rect { Rect(minX: 0, minY: 0, maxX: 800, maxY: 600) }
    public var placeFillBox: Rect? { selected?.frame }
    public var placeFormats: Set<PlacedFormat> { [.png, .svg] }
    /// The selected rect's picture in its current frame, and its asset.
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? {
        guard let rect = selected, var image = rect.placed, let asset = assets.byID[image.assetID] else { return nil }
        image.box = rect.frame
        return (String(rect.id), image, asset)
    }
    /// A PNG's width and height from its IHDR chunk (bytes 16 to 23, big-endian); anything else is refused.
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        let header = [UInt8](data.prefix(24))
        guard format == .png, header.count == 24 else { throw CatalogError.unavailable(id: "place.image", why: PlaceRules.formatHelp) }
        let word = { (at: Int) in Double(header[at..<at + 4].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }) }
        return Size(width: word(16), height: word(20))
    }
    /// Adds a rect named after the file in `image.box` showing `asset`, selects it, as the step `name`.
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String {
        let id = (rects.map(\.id).max() ?? 0) + 1, box = image.box
        history.record(name, rects)
        assets = assets.adding(asset)
        var rect = FakeRect(id: id, name: asset.name, x: box.minX, y: box.minY, w: box.width, h: box.height)
        rect.placed = image
        rects.append(rect); selection = id
        return String(id)
    }
    /// Sets the selected rect's picture and its frame to `image.box`, as the step `name` (one per `drag` token).
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws {
        let index = try editableIndex("place")
        history.record(name, rects, key: drag.map { "place.\(name):\($0)" })
        if let asset { assets = assets.adding(asset) }
        let box = image.box
        (rects[index].x, rects[index].y, rects[index].w, rects[index].h) = (box.minX, box.minY, box.width, box.height)
        rects[index].placed = image
    }
}

/// The fake's raster files: a flat mid-grey frame of the asked size, written as the specs give it, so a reader
/// decodes exactly that size. The fake paints no rects into it; only its size is the export's.
enum FakeRaster {
    /// One raster format the fake writes: its ExportFormats id and its encoder.
    struct Writer: Sendable {
        let format: String
        let encode: @Sendable ((width: Int, height: Int)) -> Data
    }
    /// Each writer sits by itself, so the fake's formats are its encoders, not a list of its own (shared-codecs rule 20).
    static let pngWriter = Writer(format: "png", encode: png)
    static let jpegWriter = Writer(format: "jpeg", encode: jpeg)
    /// The fake's raster writers, PNG first.
    static let writers = [pngWriter, jpegWriter]
    /// A baseline greyscale JPEG (ITU T.81): every 8 × 8 block is grey 128, so each codes as DC difference 0 and EOB,
    /// one 1-bit code each from Huffman tables of one code; the scan's spare bits are 1s.
    static func jpeg(_ size: (width: Int, height: Int)) -> Data {
        let wide = [UInt8(truncatingIfNeeded: size.width >> 8), UInt8(truncatingIfNeeded: size.width)]
        let high = [UInt8(truncatingIfNeeded: size.height >> 8), UInt8(truncatingIfNeeded: size.height)]
        let table = { (cls: UInt8) -> [UInt8] in [0xFF, 0xC4, 0, 20, cls, 1] + [UInt8](repeating: 0, count: 15) + [0] }
        let bits = (size.width + 7) / 8 * ((size.height + 7) / 8) * 2
        var scan = [UInt8](repeating: 0, count: bits / 8)
        if bits % 8 != 0 { scan.append(0xFF >> UInt8(bits % 8)) }
        let quant: [UInt8] = [0xFF, 0xD8, 0xFF, 0xDB, 0, 67, 0] + [UInt8](repeating: 1, count: 64)
        let frame: [UInt8] = [0xFF, 0xC0, 0, 11, 8] + high + wide + [1, 1, 0x11, 0]
        let start: [UInt8] = [0xFF, 0xDA, 0, 8, 1, 1, 0x00, 0, 63, 0]
        return Data(quant + frame + table(0x00) + table(0x10) + start + scan + [0xFF, 0xD9])
    }
    /// A 1-bit indexed PNG (W3C PNG): one grey palette entry, every row filter 0 and index 0, in stored zlib blocks.
    static func png(_ size: (width: Int, height: Int)) -> Data {
        let raw = size.height * (1 + (size.width + 7) / 8)
        var zlib: [UInt8] = [0x78, 0x01]
        for start in stride(from: 0, to: raw, by: 65_535) {
            let n = min(65_535, raw - start)
            zlib += [start + n == raw ? 1 : 0, UInt8(n & 0xFF), UInt8(n >> 8), UInt8(~n & 0xFF), UInt8((~n >> 8) & 0xFF)]
            zlib += [UInt8](repeating: 0, count: n)
        }
        zlib += word(((raw % 65_521) << 16) | 1)  // Adler-32 of `raw` zero bytes
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let header = chunk("IHDR", word(size.width) + word(size.height) + [1, 3, 0, 0, 0])
        return Data(signature + header + chunk("PLTE", [128, 128, 128]) + chunk("IDAT", zlib) + chunk("IEND", []))
    }
    /// One PNG chunk: its length, type, body and CRC-32 over type and body.
    static func chunk(_ type: String, _ body: [UInt8]) -> [UInt8] {
        let tagged = Array(type.utf8) + body
        var crc = UInt32.max
        for byte in tagged {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = crc & 1 == 0 ? crc >> 1 : (crc >> 1) ^ 0xEDB8_8320 }
        }
        return word(body.count) + tagged + word(Int(~crc))
    }
    static func word(_ value: Int) -> [UInt8] { [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) } }
}

extension CommandCatalog {
    /// A catalog with no commands, which no id check can refuse: an app's catalog before it adopts any.
    public static func empty(app: String) -> CommandCatalog {
        CommandCatalog(emptyFor: app)
    }
    /// The empty catalog's fields, set directly: no specs, and a history with no steps.
    private init(emptyFor app: String) { (self.app, self.specs, self.history) = (app, [], { _ in History<Int>() }) }
}
