// ScriptRunner.swift (afterglow-cli CL-2 stub, CL-7 body): `afterglow run
// <script.jobs.json>`, which runs a versioned list of steps over a set of
// input files and writes each output by name template. CL-7 validates the
// whole script, plans every output and refuses collisions before anything
// runs or is written; until then it exits 69 naming its slice.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Runs `*.jobs.json` scripts.
public enum ScriptRunner {
    /// The slice that builds the runner.
    public static let slice = "CL-batch"

    /// Runs the script at `script` among `apps`, printing its report on `io`'s stdout. `dryRun` prints the
    /// plan and writes nothing; `force` lets outputs replace files. Returns the exit code.
    /// CL-2 stub: exits 69 (`notBuilt`) naming CL-batch.
    public static func run(_ script: String, apps: [HeadlessApp], dryRun: Bool, force: Bool, io: any CLIIO) -> Int32 {
        CLI.notBuilt("afterglow run \(script) is not built yet (slice \(slice))", io: io)
    }
}
