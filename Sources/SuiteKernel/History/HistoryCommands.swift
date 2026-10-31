// HistoryCommands.swift: the history commands every app on the kernel `History` registers with one line,
// `+ HistoryCommands.specs(<X>Workspace.self)`. `history.read` lists the steps and who made each,
// `history.jump` moves through them, and `history.begin` / `history.end` / `history.undo-request` give an
// agent a named request span. Undoing a request reuses the app's own jump, so its mid-drag and mid-stroke
// guards hold; it is refused unless the request's steps are exactly the applied tail (any later step,
// by anyone, refuses it).

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
    /// Who made each of `steps`, in the same order.
    public var origins: [StepOrigin]
    /// The open request span's name, nil when none is open.
    public var openRequest: String?

    /// A listing; `origins` nil means every step is the user's.
    public init(base: String, steps: [String], index: Int, savedIndex: Int? = nil, origins: [StepOrigin]? = nil, openRequest: String? = nil) {
        (self.base, self.steps, self.index, self.savedIndex) = (base, steps, index, savedIndex)
        (self.origins, self.openRequest) = (origins ?? steps.map { _ in .user }, openRequest)
    }
}

extension History {
    /// This history as the panel lists it, the state before its first step named `base`. `savedIndex` is the
    /// position whose step id is the saved one, nil when that state rolled past the limit or was undone and replaced.
    public func listing(base: String) -> HistoryListing {
        let all = undoSteps + redoSteps.reversed()
        let ids = [all.first?.idBefore ?? currentStepID] + all.map(\.idAfter)
        return HistoryListing(base: base, steps: steps, index: index, savedIndex: ids.firstIndex(of: savedStepID),
                              origins: all.map(\.origin), openRequest: openRequest)
    }

    /// Opens the request span `name`, or closes the open one when `name` is nil; false when that can't happen.
    public mutating func setRequest(_ name: String?) -> Bool {
        if let name { beginRequest(name) } else { endRequest() }
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
    /// Opens the request span `name` (nil closes the open one) on the document's history: `History.setRequest`.
    mutating func setHistoryRequest(_ name: String?) -> Bool
}

public enum HistoryCommands {
    /// Why `history.jump` can't run on a document with no steps.
    static let noStepsHelp = "There are no steps yet."

    struct Empty: Codable, Sendable {}
    struct JumpParams: Codable, Sendable { var index: Int }
    struct NameParams: Codable, Sendable { var name: String }
    static let noRequestHelp = "No request is open."
    static let noRequestStepsHelp = "No applied step belongs to a request."
    /// True when an applied step belongs to a request.
    static func hasRequestSteps(_ listing: HistoryListing) -> Bool { listing.origins.prefix(listing.index).contains { $0.request != nil } }

    static let count = ParamSchema.integer("How many steps are applied, 0 for the state before the first.", minimum: 0)
    static let listing = ParamSchema.object(
        ["base": .string("The state before the first step, \"Open\" or \"New Image\"."),
         "steps": .array(of: .string("A step's name.")), "index": count,
         "savedIndex": .optional(.integer("The applied count at the last save.", minimum: 0)),
         "origins": .array(of: .object(
            ["kind": .string("Who made the step.", oneOf: ["user", "agent"]),
             "client": .optional(.string("The agent's MCP client name.")),
             "request": .optional(.string("The request span the agent's step belongs to."))], required: ["kind"])),
         "openRequest": .optional(.string("The open request span's name."))],
        required: ["base", "steps", "index", "savedIndex", "origins"])
    static let name = ParamSchema.object(["name": .string("The request's name, \"AI: Birds\".", maxLength: 128)], required: ["name"])

    /// The history commands on `target`: `history.read` a query; the jump, the request span and its undo view
    /// changes like `edit.undo`, which record no step.
    public static func specs<T: HistoryJumping>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("history.read", title: "Read History", summary: "Reads the history: the state before the first step, every step's name and who made it, how many are applied, which was saved and the open request.",
                   kind: .query, params: Empty.self, schema: .none, result: listing, example: .object([:])) { doc, _ in doc.historyListing },
            .typed("history.jump", title: "Jump in History", summary: "Undoes or redoes until the given number of steps is applied; the jump records no step.",
                   kind: .view, params: JumpParams.self, schema: .object(["index": count], required: ["index"]),
                   example: .object(["index": .number(0)]),
                   availability: { $0.historyListing.steps.isEmpty ? .unavailable(noStepsHelp) : .available }) { doc, p in try jump(&doc, to: p.index) },
            .typed("history.begin", title: "Begin Request", summary: "Opens a named request: each step an agent records until history.end carries its name, so history.undo-request can undo them together.",
                   kind: .view, params: NameParams.self, schema: name, example: .object(["name": .string("AI: Birds")])) { doc, p in
                guard doc.setHistoryRequest(p.name) else {
                    throw CatalogError.failed(id: "history.begin", message: "Request \(doc.historyListing.openRequest ?? "") is open; end it first.")
                }
                return JSONValue.object([:])
            },
            .typed("history.end", title: "End Request", summary: "Closes the open request; later steps carry no request.",
                   kind: .view, params: Empty.self, schema: .none, example: .object([:]),
                   availability: { $0.historyListing.openRequest == nil ? .unavailable(noRequestHelp) : .available }) { doc, _ in
                _ = doc.setHistoryRequest(nil)
                return JSONValue.object([:])
            },
            .typed("history.undo-request", title: "Undo Request", summary: "Undoes every step of the named request in one call. Refused when any later step follows the request's steps.",
                   kind: .view, params: NameParams.self, schema: name, example: .object(["name": .string("AI: Birds")]),
                   availability: { hasRequestSteps($0.historyListing) ? .available : .unavailable(noRequestStepsHelp) }) { doc, p in try undoRequest(&doc, p.name) },
        ]
    }

    /// `history.undo-request`'s body: undoes the applied tail of steps whose request is `name` through the
    /// document's own jump. Throws, changing nothing, when no applied step has that request or a step
    /// outside it follows one that does.
    static func undoRequest<T: HistoryJumping>(_ doc: inout T, _ name: String) throws -> JSONValue {
        let listing = doc.historyListing
        let applied = listing.origins.prefix(listing.index)
        let tail = applied.reversed().prefix { $0.request == name }.count
        guard applied.contains(where: { $0.request == name }) else {
            throw CatalogError.failed(id: "history.undo-request", message: "There is no request \(name).")
        }
        guard tail > 0, !applied.dropLast(tail).contains(where: { $0.request == name }) else {
            throw CatalogError.failed(id: "history.undo-request", message: "Later steps follow request \(name); undo them first.")
        }
        try doc.jumpHistory(to: listing.index - tail)
        return .object(["undone": .number(Double(tail))])
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
