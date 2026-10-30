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

extension CatalogError: CustomStringConvertible {
    /// The refusal in words, naming the command: what a batch report's `error` holds.
    public var description: String {
        switch self {
        case .unknownCommand(let id): "There is no command \(id)."
        case .malformedParams(let id, let issues):
            "\(id) params: " + issues.map { "\($0.path.isEmpty ? "/" : $0.path) \($0.message)" }.joined(separator: "; ")
        case .unavailable(let id, let why): "\(id) is unavailable: \(why)"
        case .failed(let id, let message): "\(id) failed: \(message)"
        case .notBuilt(let id, let feature): "\(id) is not built yet (\(feature))."
        }
    }
}

/// Why a catalog refused its specs: an id that breaks the id rule, or one registered twice.
public enum CatalogIDError: Error, Hashable, Sendable {
    case badID(String), duplicateID(String)
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
    /// A catalog of `specs`. Throws `CatalogIDError` on an id that breaks the id rule or is registered twice.
    public init(app: String, _ specs: [CommandSpec<Target>], history: @escaping @Sendable (Target) -> any HistoryReading) throws {
        var seen = Set<String>()
        for spec in specs {
            guard Self.isValidID(spec.id) else { throw CatalogIDError.badID(spec.id) }
            guard seen.insert(spec.id).inserted else { throw CatalogIDError.duplicateID(spec.id) }
        }
        (self.app, self.specs, self.history) = (app, specs, history)
    }
    /// The id rule: 1 to 64 of lowercase letters, digits, dots and hyphens, starting with a letter,
    /// each dot-separated part non-empty ("layer.add", "doc.export-json").
    public static func isValidID(_ id: String) -> Bool {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        guard (1...64).contains(id.count), id.first?.isLowercase == true else { return false }
        return id.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0.allSatisfy(allowed.contains) }
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
    /// Runs `id` with `params` on `target`: checks the id, validates the params, checks availability, then runs on a
    /// copy and commits it only on success, so every refusal leaves `target` unchanged. An edit's outcome names the
    /// undo step the target's history now reads; any other kind's is nil.
    public func run(_ id: String, params: JSONValue, on target: inout Target) throws(CatalogError) -> CommandOutcome {
        guard let spec = spec(id) else { throw .unknownCommand(id) }
        let issues = spec.params.validate(params)
        guard issues.isEmpty else { throw .malformedParams(id: id, issues) }
        if let why = spec.availability(target).why { throw .unavailable(id: id, why: why) }
        var copy = target
        let result = try Self.perform(spec, params, on: &copy)
        target = copy
        return CommandOutcome(result: result, undoStep: spec.undoable ? history(target).undoName : nil)
    }
    /// Runs `id` as `run(_:params:on:)` does, with every step it records made by `origin`: the one place a live
    /// call marks its steps as an agent's.
    public func run(_ id: String, params: JSONValue, on target: inout Target, origin: StepOrigin) throws(CatalogError) -> CommandOutcome {
        var copy = target
        let outcome = StepOrigin.$current.withValue(origin) { () -> Result<CommandOutcome, CatalogError> in
            do throws(CatalogError) { return .success(try run(id, params: params, on: &copy)) } catch { return .failure(error) }
        }
        let done = try outcome.get()
        target = copy
        return done
    }
    /// `spec`'s run on `target`; a `CatalogError` passes through, any other error becomes `failed` in its words.
    private static func perform(_ spec: CommandSpec<Target>, _ params: JSONValue, on target: inout Target) throws(CatalogError) -> JSONValue {
        do { return try spec.run(&target, params) }
        catch let error as CatalogError { throw error }
        catch { throw .failed(id: spec.id, message: String(describing: error)) }
    }
    /// Runs one envelope step on `target`.
    public func run(_ step: CommandEnvelope, on target: inout Target) throws(CatalogError) -> CommandOutcome {
        try run(step.id, params: step.params, on: &target)
    }
    /// Runs `steps` in order, stopping at the first refusal; `atomic` puts the target back when one stops it.
    /// The report lists every step tried, the refused one last.
    public func runBatch(_ steps: [CommandEnvelope], on target: inout Target, atomic: Bool) -> BatchReport {
        let start = target
        var report = BatchReport(steps: [], stoppedAt: nil, rolledBack: false)
        for (index, step) in steps.enumerated() {
            do {
                let outcome = try run(step, on: &target)
                report.steps.append(.init(id: step.id, ok: true, undoStep: outcome.undoStep, error: nil))
            } catch {
                report.steps.append(.init(id: step.id, ok: false, undoStep: nil, error: error.description))
                report.stoppedAt = index
                if atomic { target = start; report.rolledBack = true }
                break
            }
        }
        return report
    }
}
