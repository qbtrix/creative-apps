// HistoryCommands.swift (autosave-history AH-1 specs with real ids, schemas and availability, runs throwing
// `HistoryCommands.notBuilt`; AH-6 bodies): the History panel's two commands every app registers with one line,
// `+ HistoryCommands.specs(<X>Workspace.self)`, read from the kernel `History` the app already runs on.

/// What the History panel shows: the state before the first step, every step, and where the document is.
public struct HistoryListing: Hashable, Sendable, Codable {
    /// "Open", "New Image": the state before the first step.
    public var base: String
    /// Every step's name, oldest first, undone ones included.
    public var steps: [String]
    /// How many steps are applied, 0...steps.count.
    public var index: Int
    /// The applied count at the last save; nil when no listed state is saved.
    public var savedIndex: Int?

    public init(base: String, steps: [String], index: Int, savedIndex: Int? = nil) {
        (self.base, self.steps, self.index, self.savedIndex) = (base, steps, index, savedIndex)
    }
}

extension History {
    /// This history as the panel lists it, the state before its first step named `base`.
    /// Stub: `base` alone, no steps; AH-6 fills this in.
    public func listing(base: String) -> HistoryListing { HistoryListing(base: base, steps: [], index: 0) }
}

/// A document whose history the panel lists and jumps in.
public protocol HistoryJumping: Sendable {
    /// The document's history as the panel lists it.
    var historyListing: HistoryListing { get }
    /// Undoes or redoes until `index` steps are applied: no new step, the open run ended.
    mutating func jumpHistory(to index: Int) throws
}

public enum HistoryCommands {
    /// What a history command's run throws until AH-6 builds the bodies.
    public static let notBuilt = CatalogError.notBuilt(id: "history", feature: "autosave-history AH-6")
    /// Why `history.jump` can't run on a document with no steps.
    static let noStepsHelp = "There are no steps yet."

    struct Empty: Codable, Sendable {}
    struct JumpParams: Codable, Sendable { var index: Int }

    static let count = ParamSchema.integer("How many steps are applied, 0 for the state before the first.", minimum: 0)
    static let listing = ParamSchema.object(
        ["base": .string("The state before the first step, \"Open\" or \"New Image\"."),
         "steps": .array(of: .string("A step's name.")), "index": count,
         "savedIndex": .optional(.integer("The applied count at the last save.", minimum: 0))],
        required: ["base", "steps", "index", "savedIndex"])

    /// The two history commands on `target`: `history.read` a query, `history.jump` a view change like `edit.undo`.
    public static func specs<T: HistoryJumping>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("history.read", title: "Read History", summary: "Reads the history: the state before the first step, every step's name, how many are applied and which was saved.",
                   kind: .query, params: Empty.self, schema: .none, result: listing, example: .object([:])) { _, _ in try stub() },
            .typed("history.jump", title: "Jump in History", summary: "Undoes or redoes until the given number of steps is applied; the jump records no step.",
                   kind: .view, params: JumpParams.self, schema: .object(["index": count], required: ["index"]),
                   example: .object(["index": .number(0)]),
                   availability: { $0.historyListing.steps.isEmpty ? .unavailable(noStepsHelp) : .available }) { _, _ in try stub() },
        ]
    }

    /// Every run until AH-6: refuses with `notBuilt`.
    static func stub() throws -> JSONValue { throw notBuilt }
}
