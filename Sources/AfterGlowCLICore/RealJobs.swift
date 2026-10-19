// RealJobs.swift (afterglow-cli CL-2 stub, CL-9 body): the real-jobs
// harness. A real job is a folder `Tests/RealJobs/<app>/<job>/` holding a
// `*.jobs.json` with an `expect` block; CL-9 runs it through ScriptRunner
// and compares each output (sha256, JSON equal, or pixels within a
// tolerance), skipping a job not meant for this platform with its why.
// Until then it exits 69 naming its slice.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Runs real jobs and checks their outputs against their expectations.
public enum RealJobs {
    /// The slice that builds the harness.
    public static let slice = "CL-jobs"

    /// Runs the job in the folder `job` among `apps` and prints one JSON report naming each output that
    /// differs from its expectation, or the skip and its reason. Returns the exit code.
    /// CL-2 stub: exits 69 (`notBuilt`) naming CL-jobs.
    public static func check(_ job: String, apps: [HeadlessApp], io: any CLIIO) -> Int32 {
        CLI.notBuilt("real job \(job) is not built yet (slice \(slice))", io: io)
    }
}
