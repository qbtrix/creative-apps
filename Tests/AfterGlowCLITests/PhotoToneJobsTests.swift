// PhotoToneJobsTests.swift (tone-controls PT-7): Photo's three tone real jobs, RJ-P12 white-balance, RJ-P13
// backlit and RJ-P14 sharpen-web, run live. Each folder holds a `*.jobs.json` (no longer `.jobs.pending.json`)
// with its input and the reference its export is compared to, names no pending task, and its run writes every
// output its `expect` block names, so a reference named for a file the export never writes (a `.jpg` where
// JPEG export writes `.jpeg`) fails here. The pixel compare itself waits on image-codecs, as every job's does.
import AfterGlowCLICore
import Foundation
import Testing

struct PhotoToneJobsTests {
    static let jobs = ["white-balance", "backlit", "sharpen-web"].map { "\(RealJobsHarness.jobsTree)/photo/\($0)" }

    @Test(arguments: jobs) func runsLiveAndWritesWhatItExpects(job: String) throws {
        #expect(RealJobsHarness.scripts(in: job).count == 1, "\(job) has no live .jobs.json")
        #expect(try AllAppsCatalogTests.pending(job) == nil, "\(job) still names a pending task")
        let io = RealJobsHarness.mount(job)
        #expect(io.files.keys.contains { $0.hasPrefix("\(job)/input/") }, "\(job) has no input")
        let code = RealJobs.check(job, apps: RealJobsHarness.apps, io: io)
        let report = try #require(RealJobsHarness.report(io), "\(job) printed \(io.stdout)")
        #expect(code == 0, "\(job) exited \(code): \(RealJobsHarness.printed(io))")
        // Passed, or waiting only on pixels: never a platform skip, never a failed expectation.
        let waitsOnPixels = if case .string(let why)? = report["skipped"] { why.hasPrefix("waits on image-codecs") } else { false }
        #expect(report["ok"] == .bool(true) || waitsOnPixels, "\(job): \(RealJobsHarness.printed(io))")
        let data = try Data(contentsOf: RealJobsHarness.root.appendingPathComponent(job)
            .appendingPathComponent(RealJobsHarness.scripts(in: job).first ?? ""))
        guard case .object(let fields) = try JSONValue(json: data), case .object(let expect)? = fields["expect"] else {
            Issue.record("\(job) has no expect block"); return
        }
        for (output, want) in expect {
            #expect(io.files["\(job)/\(output)"] != nil, "\(job) wrote no \(output)")
            guard case .object(let kinds) = want, case .object(let pixels)? = kinds["pixels"],
                  case .string(let reference)? = pixels["reference"] else { continue }
            #expect(io.files["\(job)/\(reference)"] != nil, "\(job) has no \(reference)")
        }
    }
}
