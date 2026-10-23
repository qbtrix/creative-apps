// DesignMenuState.swift (adopt-command-catalog AC-d3): what a Design menu item built from its catalog spec reads. The
// target is the focused window's workspace (a blank one with no window) plus the menu's own context, which today's
// menus fold in: Open needs a window to open into; Undo and Redo go to a focused text field's own undo when the
// workspace's `undoTarget` sends them there; Rename Page… stays off until the menu has a name field; each Align item
// is off by `alignHelps`, as the submenu was. Every other item is the catalog's availability. Run goes through the
// catalog. Linux-safe.
import SuiteKernel

public struct DesignMenuState: Sendable {
    public var workspace: DesignWorkspace
    public var hasWindow: Bool
    /// The focused text field's own undo, when Edit > Undo and Redo go there; nil when they go to the file's history.
    public var field: FieldUndo?

    /// Whether the focused field's undo manager can undo and redo.
    public struct FieldUndo: Sendable, Equatable {
        public var canUndo: Bool, canRedo: Bool
        public init(canUndo: Bool, canRedo: Bool) { (self.canUndo, self.canRedo) = (canUndo, canRedo) }
    }

    public init(workspace: DesignWorkspace = DesignWorkspace(), hasWindow: Bool = false, field: FieldUndo? = nil) {
        (self.workspace, self.hasWindow, self.field) = (workspace, hasWindow, field)
    }

    /// The id of an Arrange, Align or Distribute item: its menu title slugged under "object.".
    public static func objectID(_ title: String) -> String { "object." + DesignWorkspace.slug(title) }

    /// The catalog's spec for `id` over the menu state; a place command the catalog lacks reads the workspace's
    /// `placeActionHelp`, and any other id the catalog lacks is never available.
    public static func spec(_ id: String) -> CommandSpec<DesignMenuState> {
        if id.hasPrefix("place."), specs[id] == nil { return placeSpec(id) }
        return specs[id] ?? windowSpecs[id] ?? .typed(id, title: id, summary: "Design has no \(id) command.", kind: .view, params: JSONValue.self,
                            example: .object([:]), availability: { _ in .unavailable("Design has no \(id) command.") }) { _, _ in JSONValue.object([:]) }
    }

    static let specs = Dictionary(uniqueKeysWithValues: DesignWorkspace.commands.map { spec in
        (spec.id, CommandSpec<DesignMenuState>.typed(
            spec.id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: spec.params,
            result: spec.result, example: spec.example, availability: { $0.availability(spec.id) }) { state, params in
            try DesignWorkspace.catalog.run(spec.id, params: params, on: &state.workspace).result
        })
    })

    /// Items that drive the window rather than the file, so the catalog has no command for them and the item's own
    /// perform does the work: View > Show History shows the window's History panel, which needs a window.
    static let windowSpecs: [String: CommandSpec<DesignMenuState>] = [
        "view.history": .typed("view.history", title: "Show History", summary: "Shows or hides this window's steps.", kind: .view,
                               params: JSONValue.self, example: .object([:]),
                               availability: { $0.hasWindow ? .available : .unavailable("Open a Design window to see its history.") }
        ) { _, _ in JSONValue.object([:]) },
    ]

    /// A place command before the catalog registers it (PD-5): off with the workspace's plain reason, never its id.
    static func placeSpec(_ id: String) -> CommandSpec<DesignMenuState> {
        .typed(id, title: "Place…", summary: "Places a PNG, JPEG or SVG file up to 32 MB as a picture.", kind: .edit,
               params: JSONValue.self, example: .object([:]),
               availability: { DesignWorkspace.reason($0.workspace.placeActionHelp(id)) }) { _, _ in JSONValue.object([:]) }
    }

    /// Whether the menu item for `id` can run, and why not.
    public func availability(_ id: String) -> Availability {
        let w = workspace
        if let edge = DesignAlignEdge.allCases.first(where: { id == Self.objectID($0.title) }) {
            return DesignWorkspace.reason(w.alignHelps[edge])
        }
        switch id {
        case "file.new": return .available
        case "file.open": return hasWindow ? .available : .unavailable("Open a Design window first.")
        case "edit.undo": return field.map { $0.canUndo ? .available : .unavailable("Nothing to undo.") } ?? base(id)
        case "edit.redo": return field.map { $0.canRedo ? .available : .unavailable("Nothing to redo.") } ?? base(id)
        case "page.rename":
            return .unavailable(w.addPageHelp ?? DesignRefusal.notBuilt("Renaming a page from the menu").help)
        default: return base(id)
        }
    }

    private func base(_ id: String) -> Availability { DesignWorkspace.catalog.availability(id, on: workspace) }
}
