// ExportRun.swift (EK-3 stub, EK-22 body): the one export run. Stubs refuse or ignore every move.
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

    /// Opens the sheet on `o`; false (and no change) while running. Stub: false until EK-22.
    public mutating func begin(_ o: Options) -> Bool { false }

    /// Starts writing `total` steps from editing; false from any other state. Stub: false.
    public mutating func start(total: Int) -> Bool { false }

    /// Reports `done` steps while running: never less than before, never more
    /// than the total; ignored in any other state. Stub: ignored until EK-22.
    public mutating func progressed(done: Int) {}

    /// Ends a running run with the written files or the error (a cancel goes idle). Stub: ignored.
    public mutating func end(_ r: Result<[String], any Error>) {}

    /// Closes the sheet: idle from editing, finished or failed. Stub: ignored until EK-22.
    public mutating func dismiss() {}
}
