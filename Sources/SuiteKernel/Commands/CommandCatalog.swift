// CommandCatalog.swift (command-catalog CC-1 stub, CC-7 body): an app's commands by id: list, describe, run, batch.

/// One step as journals and scripts write it: `{"id": "<name>", "params": {...}}`, FlareCore's envelope.
public struct CommandEnvelope: Codable, Hashable, Sendable {
    /// The command's id and its params.
    public var id: String; public var params: JSONValue
    public init(id: String, params: JSONValue) { (self.id, self.params) = (id, params) }
}

/// Why a run refused or failed; each case leaves the target unchanged.
public enum CatalogError: Error, Hashable, Sendable {
    case unknownCommand(String), malformedParams(id: String, [SchemaIssue])
    case unavailable(id: String, why: String), failed(id: String, message: String)
    case notBuilt(id: String, feature: String)
}

/// What a run returns: its result and, for an edit, the name of the undo step it recorded (nil otherwise).
public struct CommandOutcome: Hashable, Sendable {
    public var result: JSONValue; public var undoStep: String?
    public init(result: JSONValue, undoStep: String?) { (self.result, self.undoStep) = (result, undoStep) }
}

/// What a batch did: each step tried in order, the index of the one that stopped it (nil when all ran),
/// and whether an atomic batch put the target back.
public struct BatchReport: Codable, Hashable, Sendable {
    /// One step's id, whether it ran, its undo step and its error in words.
    public struct Step: Codable, Hashable, Sendable {
        public var id: String; public var ok: Bool; public var undoStep: String?; public var error: String?
        public init(id: String, ok: Bool, undoStep: String?, error: String?) { (self.id, self.ok, self.undoStep, self.error) = (id, ok, undoStep, error) }
    }
    public var steps: [Step]; public var stoppedAt: Int?; public var rolledBack: Bool
    public init(steps: [Step], stoppedAt: Int?, rolledBack: Bool) { (self.steps, self.stoppedAt, self.rolledBack) = (steps, stoppedAt, rolledBack) }
}

/// One app's commands on its `Target` document, and the history each run reads its undo step from.
public struct CommandCatalog<Target>: Sendable {
    /// The app ("photo").
    public let app: String
    /// The specs in registration order, and the target's history (the catalog never owns one).
    let specs: [CommandSpec<Target>], history: @Sendable (Target) -> any HistoryReading
    /// A catalog of `specs`. Throws on a bad or duplicate id (checked from command-catalog CC-7).
    public init(app: String, _ specs: [CommandSpec<Target>], history: @escaping @Sendable (Target) -> any HistoryReading) throws {
        (self.app, self.specs, self.history) = (app, specs, history)
    }
    /// Every id, sorted.
    public var ids: [String] { specs.map(\.id).sorted() }
    /// The spec registered under `id`, nil when there is none.
    public func spec(_ id: String) -> CommandSpec<Target>? { specs.first { $0.id == id } }
    /// Whether `id` can run on `target`; an unknown id is unavailable.
    public func availability(_ id: String, on target: Target) -> Availability {
        spec(id)?.availability(target) ?? .unavailable("There is no command \(id).")
    }
    /// What `describe` publishes for `id`, nil when there is none.
    public func describe(_ id: String) -> CommandDescription? {
        spec(id).map { CommandDescription(app: app, id: $0.id, title: $0.title, summary: $0.summary, kind: $0.kind,
                                          undoable: $0.undoable, params: $0.params.json, result: $0.result.json, example: $0.example) }
    }
    /// Every command's description, by id.
    public func describeAll() -> [CommandDescription] { ids.compactMap(describe) }
    /// Runs `id` with `params` on `target`. CC-1 stub: throws `notBuilt` until command-catalog CC-7.
    public func run(_ id: String, params: JSONValue, on target: inout Target) throws(CatalogError) -> CommandOutcome {
        throw .notBuilt(id: id, feature: "command-catalog CC-7")
    }
    /// Runs one envelope step on `target`.
    public func run(_ step: CommandEnvelope, on target: inout Target) throws(CatalogError) -> CommandOutcome {
        try run(step.id, params: step.params, on: &target)
    }
    /// Runs `steps` in order, stopping at the first refusal; `atomic` puts the target back when one stops it.
    /// CC-1 stub: reports the first step as not built until command-catalog CC-7.
    public func runBatch(_ steps: [CommandEnvelope], on target: inout Target, atomic: Bool) -> BatchReport {
        guard let first = steps.first else { return BatchReport(steps: [], stoppedAt: nil, rolledBack: false) }
        let error = String(describing: CatalogError.notBuilt(id: first.id, feature: "command-catalog CC-7"))
        return BatchReport(steps: [.init(id: first.id, ok: false, undoStep: nil, error: error)], stoppedAt: 0, rolledBack: atomic)
    }
}
