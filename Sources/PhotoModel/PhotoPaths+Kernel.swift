// PhotoPaths+Kernel.swift: Photo's paths on the shared pen (#5072). The
// document keeps a list of named paths (the kernel's `VectorPath`, in canvas
// pixels), saved in photo/document.json; the workspace conforms to SuiteKernel's
// `PathEditTarget`, so the Pen's draft, point edits and `PathCommands` all run
// on PenRules and AnchorEdit with no Photo copy of their logic. Adding or
// changing a path is one undo step that keeps the whole list (`PhotoEdit.paths`);
// a drag's edits fold under its token. Which path shows its points, the draft
// and the picked anchors are view state, outside History, and a new or opened
// image resets them. The catalog runs the shared `path.*` specs plus
// `paths.list` and `paths.edit`; `runPath` sends the overlay's intents through
// it. Linux-safe.
import SuiteKernel

/// One path in the document's path list, in canvas pixels.
public struct PhotoPath: Hashable, Sendable, Codable {
    public let id: String
    public var name: String
    public var path: VectorPath

    public init(id: String, name: String, path: VectorPath) {
        (self.id, self.name, self.path) = (id, name, path)
    }
}

/// The paths and the Pen's view state, one stored value on the workspace.
struct PhotoPathState: Sendable, Equatable {
    var paths: [PhotoPath] = []
    /// The path whose points show and edit; nil for none.
    var editingID: String?
    var draft: PenDraft?
    var anchors = Selection<AnchorRef>()
    /// The number in the next path's id; ids are never reused.
    var nextNumber = 1
}

extension PhotoWorkspace: PathEditTarget {
    /// The document's paths, in list order.
    public var paths: [PhotoPath] { pathState.paths }

    /// The path whose points the overlay shows; nil for none.
    public var editingPathID: String? { pathState.editingID }

    public var penDraft: PenDraft? {
        get { pathState.draft }
        set { pathState.draft = newValue }
    }

    public var anchorSelection: Selection<AnchorRef> {
        get { pathState.anchors }
        set { pathState.anchors = newValue }
    }

    /// The editing path, already in canvas pixels.
    public var pathInEdit: PathInEdit? {
        guard let id = pathState.editingID, let path = paths.first(where: { $0.id == id }) else { return nil }
        return PathInEdit(id: id, path: path.path, toDocument: .identity)
    }

    /// Why paths can't change: no image is open.
    public var pathHelp: String? { canvas == nil ? "Open an image to draw a path." : nil }

    /// Adds `path` as "Path N" (the lowest N no path uses), shows its points, and returns its id: one step named `name`.
    public mutating func addPath(_ path: VectorPath, name: String) throws -> String {
        if let pathHelp { throw CatalogError.unavailable(id: "path", why: pathHelp) }
        var number = 1
        while paths.contains(where: { $0.name == "Path \(number)" }) { number += 1 }
        recordPaths(named: name)
        let id = "path-\(pathState.nextNumber)"
        pathState.nextNumber += 1
        pathState.paths.append(PhotoPath(id: id, name: "Path \(number)", path: path))
        pathState.editingID = id
        return id
    }

    /// Replaces the editing path with `path`: one step named `name`, every call under one `drag` token folded into it.
    public mutating func setPath(_ path: VectorPath, name: String, drag: String?) throws {
        guard let id = pathState.editingID, let at = paths.firstIndex(where: { $0.id == id }) else {
            throw CatalogError.unavailable(id: "path", why: pathHelp ?? "Select a path to edit its points.")
        }
        recordPaths(named: name, coalescing: drag.map { "path-\(id)-\(name)-\($0)" })
        pathState.paths[at].path = path
    }

    /// Shows `id`'s points (nil: none), dropping the picked anchors. View state, not an undo step; an unknown id is ignored.
    public mutating func editPath(_ id: String?) {
        guard id == nil || paths.contains(where: { $0.id == id }) else { return }
        pathState.editingID = id
        pathState.anchors.clear()
    }

    /// Records the path list and editing path as they are, before a change, and moves `revision` with no canvas
    /// damage, so the window's autosave sees the edit.
    mutating func recordPaths(named name: String, coalescing: String? = nil) {
        record(.paths(paths, editing: pathState.editingID), named: name, coalescing: coalescing)
        touch(.none)
    }

    /// Puts back `list` and `editing` for undo and returns what they replaced; the picked anchors go, since their
    /// points may be gone.
    mutating func applyPaths(_ list: [PhotoPath], editing: String?) -> PhotoEdit {
        let inverse = PhotoEdit.paths(paths, editing: pathState.editingID)
        (pathState.paths, pathState.editingID) = (list, editing)
        pathState.anchors.clear()
        touch(.none)
        return inverse
    }

    /// Starts an opened document's paths: none shows its points, and new ids count past the loaded ones.
    mutating func loadPaths(_ list: [PhotoPath]) {
        let numbers = list.compactMap { $0.id.hasPrefix("path-") ? Int($0.id.dropFirst(5)) : nil }
        pathState = PhotoPathState(paths: list, nextNumber: (numbers.max() ?? 0) + 1)
    }
}

extension PhotoWorkspace {
    struct PathPickParams: Codable, Sendable { var id: String? }

    /// The twelve shared path commands, then Photo's two for its path list: read it, and pick the path in edit.
    static let pathCommands: [CommandSpec<PhotoWorkspace>] = PathCommands.specs(PhotoWorkspace.self) + [
        .typed("paths.list", title: "List Paths", summary: "Lists the document's paths, each with its id and name.", kind: .query,
               params: NoParams.self, schema: .none, example: .object([:]), availability: gate { $0.pathHelp }) { w, _ in
            JSONValue.object(["paths": .array(w.paths.map { JSONValue.object(["id": .string($0.id), "name": .string($0.name)]) })])
        },
        .typed("paths.edit", title: "Edit Path Points", summary: "Shows the points of the path with this id for editing; no id hides them.",
               kind: .view, params: PathPickParams.self,
               schema: .object(["id": .optional(.string("A path id from paths.list.", maxLength: 64))], required: ["id"]),
               example: .object([:]), availability: gate { $0.pathHelp }) { w, p in
            guard p.id == nil || w.paths.contains(where: { $0.id == p.id }) else {
                throw CatalogError.unavailable(id: "paths.edit", why: "There is no path \(p.id ?? "").")
            }
            w.editPath(p.id)
            return JSONValue.object([:])
        },
    ]

    /// Runs one Pen or point-editor gesture as its command in the catalog; a refusal goes to the status line.
    public mutating func runPath(_ intent: PathIntent) {
        let command = intent.command
        do {
            _ = try Self.catalog.run(command.id, params: command.params, on: &self)
        } catch {
            if case .unavailable(_, let why) = error { statusMessage = why } else { statusMessage = error.description }
        }
    }
}
