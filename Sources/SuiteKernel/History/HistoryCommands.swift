// HistoryCommands.swift (autosave-history AH-1 specs with real ids, schemas and availability, AH-6 bodies):
// the History panel's two commands every app registers with one line,
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
    /// This history as the panel lists it, the state before its first step named `base`. `savedIndex` is the
    /// position whose step id is the saved one, nil when that state rolled past the limit or was undone and replaced.
    public func listing(base: String) -> HistoryListing {
        let all = undoSteps + redoSteps.reversed()
        let ids = [all.first?.idBefore ?? currentStepID] + all.map(\.idAfter)
        return HistoryListing(base: base, steps: steps, index: index, savedIndex: ids.firstIndex(of: savedStepID))
    }

    /// The jump a `HistoryJumping` conformance makes: ends the open run, so the next edit never folds into the
    /// step the jump landed on, then undoes or redoes through `apply` until `index` steps are applied.
    public mutating func jumpEndingRun(to index: Int, _ apply: (Payload) -> Payload) {
        endRun()
        jump(to: index, apply)
    }
}

/// A document whose history the panel lists and jumps in.
public protocol HistoryJumping: Sendable {
    /// The document's history as the panel lists it.
    var historyListing: HistoryListing { get }
    /// Undoes or redoes until `index` steps are applied: no new step, the open run ended.
    mutating func jumpHistory(to index: Int) throws
}

public enum HistoryCommands {
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
                   kind: .query, params: Empty.self, schema: .none, result: listing, example: .object([:])) { doc, _ in doc.historyListing },
            .typed("history.jump", title: "Jump in History", summary: "Undoes or redoes until the given number of steps is applied; the jump records no step.",
                   kind: .view, params: JumpParams.self, schema: .object(["index": count], required: ["index"]),
                   example: .object(["index": .number(0)]),
                   availability: { $0.historyListing.steps.isEmpty ? .unavailable(noStepsHelp) : .available }) { doc, p in try jump(&doc, to: p.index) },
        ]
    }

    /// `history.jump`'s body: an index outside `0...steps.count` throws its sentence and leaves `doc` as it was;
    /// any other lands there through the document's own jump, which records no step and ends the open run.
    static func jump<T: HistoryJumping>(_ doc: inout T, to index: Int) throws -> JSONValue {
        guard (0...doc.historyListing.steps.count).contains(index) else {
            throw CatalogError.failed(id: "history.jump", message: "There is no step \(index).")
        }
        try doc.jumpHistory(to: index)
        return .object([:])
    }
}
