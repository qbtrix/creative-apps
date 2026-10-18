// ExportRun.swift (EK-3 stub, EK-22 body): the one export run and its moves.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One export, generic over the app's options: `idle` (no sheet), `editing`
/// (the sheet is open on options), `running` (done of total steps),
/// `finished` (the written files' names) or `failed` (the error in words).
public enum ExportRun<Options: Hashable & Sendable>: Hashable, Sendable {
    case idle, editing(Options), running(Options, done: Int, total: Int), finished(Options, [String]), failed(Options, String)

    /// Opens the sheet on `o`; false (and no change) while running.
    public mutating func begin(_ o: Options) -> Bool {
        if case .running = self { return false }
        self = .editing(o)
        return true
    }

    /// Starts writing `total` steps from editing; false from any other state.
    public mutating func start(total: Int) -> Bool {
        guard case .editing(let o) = self else { return false }
        self = .running(o, done: 0, total: max(total, 0))
        return true
    }

    /// Reports `done` steps while running: never less than before, never more
    /// than the total; ignored in any other state.
    public mutating func progressed(done: Int) {
        guard case .running(let o, let old, let total) = self else { return }
        let forward = max(done, old)
        self = .running(o, done: min(forward, total), total: total)
    }

    /// Ends a running run with the written files or the error (a cancel goes idle).
    public mutating func end(_ r: Result<[String], any Error>) {
        guard case .running(let o, _, _) = self else { return }
        switch r {
        case .success(let files): self = .finished(o, files)
        case .failure(let error) where error is CancellationError: self = .idle
        case .failure(let error): self = .failed(o, String(describing: error))
        }
    }

    /// Closes the sheet: idle from editing, finished or failed; a running run stays.
    public mutating func dismiss() {
        if case .running = self { return }
        self = .idle
    }
}
