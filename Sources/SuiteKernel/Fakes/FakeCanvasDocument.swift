// FakeCanvasDocument.swift (command-catalog CC-2): a Linux headless document of named rects, with the six
// commands the catalog's tests, the gallery page, the afterglow CLI and the MCP server drive before any app adopts;
// file-flow SF-9 adds the five file-flow commands over fixed readers, so RJ-X43 runs `file.drop` on the CLI.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One named rect on the fake canvas; a locked one refuses move and remove.
public struct FakeRect: Codable, Hashable, Sendable {
    /// The rect's id, its name ("Rect 1"), its frame and whether it is locked.
    public var id: Int, name: String, x, y, w, h: Double, locked: Bool
    public init(id: Int, name: String, x: Double, y: Double, w: Double, h: Double, locked: Bool = false) {
        (self.id, self.name, self.x, self.y, self.w, self.h, self.locked) = (id, name, x, y, w, h, locked)
    }
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
    public init(rects: [FakeRect] = [], selection: Int? = nil, recents: [RecentFileEntry] = []) {
        (self.rects, self.selection, self.recents) = (rects, selection, recents)
    }

    /// The document every example runs on: "Rect 1" selected and free, "Rect 2" locked.
    public static let fixture = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 10, y: 10, w: 100, h: 60),
                                                           FakeRect(id: 2, name: "Rect 2", x: 140, y: 40, w: 80, h: 80, locked: true)],
                                                   selection: 1, recents: [example])
    /// The fixture's one recent file, the file-flow examples' `path:/tmp/example`.
    static let example = RecentFileEntry(fileID: "path:/tmp/example", name: "example", path: "/tmp/example", app: app,
                                         lastUsed: Date(timeIntervalSince1970: 0))
    public static let app = "fake", openExtensions = ["fake"], exportFormats = ["json"]

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

    /// The rects as JSON, keys sorted: the native format and the `json` export.
    public func save() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(rects)
    }
    public static func open(_ data: Data, name: String) throws -> FakeCanvasDocument {
        FakeCanvasDocument(rects: try JSONDecoder().decode([FakeRect].self, from: data))
    }
    public static func new(_ options: JSONValue) throws -> FakeCanvasDocument { FakeCanvasDocument() }
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] {
        guard format == "json" else { throw CatalogError.failed(id: "doc.export-json", message: "The fake exports json, not \(format).") }
        return [ExportedFile(suggestedName: "canvas.json", format: "json", data: try save())]
    }
    public func summary() -> JSONValue {
        .object(["rects": .number(Double(rects.count)), "selected": selected.map { .string($0.name) } ?? .null])
    }

    /// The fake's thirteen ids: its six commands, `edit.undo` and `edit.redo`, and the five file-flow commands.
    /// Empty only if an id were refused.
    public static let catalog = (try? CommandCatalog<FakeCanvasDocument>(
        app: app, specs + FileFlowCommands.specs(FakeCanvasDocument.self), history: { $0.history })) ?? .empty(app: app)
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

extension CommandCatalog {
    /// A catalog with no commands, which no id check can refuse: an app's catalog before it adopts any.
    public static func empty(app: String) -> CommandCatalog {
        CommandCatalog(emptyFor: app)
    }
    /// The empty catalog's fields, set directly: no specs, and a history with no steps.
    private init(emptyFor app: String) { (self.app, self.specs, self.history) = (app, [], { _ in History<Int>() }) }
}
