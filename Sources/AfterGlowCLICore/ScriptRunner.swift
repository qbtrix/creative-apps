// ScriptRunner.swift (afterglow-cli CL-2 stub, CL-7 body): `afterglow run
// <script.jobs.json>`, which runs a versioned list of steps over a set of
// input files and writes each output by name template. Everything is checked
// before anything is written: the script (Script.parse, Script.check), every
// input pattern, and every planned output (two inputs on one path, or a file
// already there without --force, is 73). Each input then runs through the
// catalog's runBatch, all or none when atomic, and one report prints. A
// `file.drop` step's paths are read relative to the script (DropFiles).
// Files are reached only through CLIIO.
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
    /// plan and writes nothing; `force` lets outputs replace files. Returns the exit code: 0 ok, 64 an unknown
    /// app, step or format, 65 a malformed script or a pattern matching nothing, 70 a run in which some input
    /// refused (the report still prints), 73 a collision, 74 a missing script or a failed read or write.
    public static func run(_ script: String, apps: [HeadlessApp], dryRun: Bool, force: Bool, io: any CLIIO) -> Int32 {
        do throws(Script.Problem) {
            let plan = try Plan(script, apps: apps, io: io)
            try refuseCollisions(plan.items, force: force, io: io)
            if dryRun {
                io.out(CLI.encode(DryRun(inputs: plan.items.map { .init(input: $0.input, outputs: [$0.output]) })))
                return CLI.Exit.ok
            }
            return execute(plan, force: force, io: io)
        } catch {
            io.out(CLI.encode(CLI.Failure(error: .init(kind: error.kind, message: error.message))))
            io.err(error.message)
            return error.code
        }
    }

    /// One input and the path its output goes to.
    struct Item { let input: String; let output: String }

    /// A checked script: its app, its steps and an output path for every input, sorted by input.
    struct Plan {
        let script: Script, app: HeadlessApp, format: String, dir: String, items: [Item]

        init(_ path: String, apps: [HeadlessApp], io: any CLIIO) throws(Script.Problem) {
            let data: Data
            do { data = try io.read(path) } catch { throw Script.Problem(code: CLI.Exit.io, kind: "io", message: "can't read \(path)") }
            let script = try Script.parse(data, path: path), app = try script.check(in: apps), format = script.format(of: app)
            (self.script, self.app, self.format) = (script, app, format)
            let dir = path.split(separator: "/", omittingEmptySubsequences: false).dropLast().joined(separator: "/")
            self.dir = dir
            var found: [String] = []
            for pattern in script.inputs {
                let matches: [String]
                do { matches = try io.glob(pattern, relativeTo: dir) } catch {
                    throw Script.Problem(code: CLI.Exit.io, kind: "io", message: "can't list \(pattern)")
                }
                guard !matches.isEmpty else { throw .data("input \(pattern) matches no file") }
                found += matches
            }
            let inputs = Array(Set(found)).sorted()
            let outDir = ScriptRunner.join(dir, script.output?.dir ?? "out")
            items = inputs.enumerated().map { index, input in
                Item(input: input, output: ScriptRunner.join(outDir, script.fileName(for: input, index: index, count: inputs.count, format: format)))
            }
        }
    }

    /// `relative` resolved against the folder `dir` ("" is the working folder).
    static func join(_ dir: String, _ relative: String) -> String {
        dir.isEmpty || relative.hasPrefix("/") ? relative : dir + "/" + relative
    }

    /// Throws 73 naming the first output two inputs share, or the first already there when not forcing.
    static func refuseCollisions(_ items: [Item], force: Bool, io: any CLIIO) throws(Script.Problem) {
        var seen = Set<String>()
        for item in items {
            guard seen.insert(item.output).inserted else {
                throw Script.Problem(code: CLI.Exit.cannotCreate, kind: "exists", message: "two inputs write \(item.output)")
            }
            if !force, io.exists(item.output) {
                throw Script.Problem(code: CLI.Exit.cannotCreate, kind: "exists", message: "\(item.output) exists; pass --force to replace it")
            }
        }
    }

    /// Runs every input of `plan` and prints the report; the exit code is 74 on a failed write, 70 when an input refused.
    static func execute(_ plan: Plan, force: Bool, io: any CLIIO) -> Int32 {
        let atomic = plan.script.atomic ?? true
        var report = Report(ok: true, inputs: [], written: 0, refused: 0)
        var code = CLI.Exit.ok
        for item in plan.items {
            var entry = Report.Input(input: item.input, steps: [], outputs: [], error: nil)
            defer { report.inputs.append(entry) }
            var session: HeadlessSession
            do {
                let name = item.input.split(separator: "/").last.map(String.init) ?? item.input
                session = try plan.app.session(open: io.read(item.input), name: name)
            } catch {
                entry.error = "can't open \(item.input): \(error)"
                report.refused += 1; code = max(code, CLI.Exit.failed)
                continue
            }
            let steps: [CommandEnvelope]
            do {
                let dropped = try DropFiles.attach(plan.script.steps, dir: plan.dir, io: io)
                session.receiveDropped(dropped.files)
                steps = dropped.steps
            } catch {
                entry.error = "can't read a dropped file: \(error)"
                report.refused += 1; code = max(code, CLI.Exit.failed)
                continue
            }
            let batch = session.runBatch(steps, atomic: atomic)
            entry.steps = batch.steps
            if let stopped = batch.stoppedAt, batch.steps.indices.contains(stopped) {
                entry.error = batch.steps[stopped].error ?? "\(batch.steps[stopped].id) refused"
                report.refused += 1; code = max(code, CLI.Exit.failed)
                if atomic { continue }
            }
            do {
                try io.write(output(of: session, plan: plan), to: item.output, replace: force)
                entry.outputs = [item.output]; report.written += 1
            } catch {
                entry.error = "can't write \(item.output): \(error)"
                code = CLI.Exit.io
            }
        }
        report.ok = code == CLI.Exit.ok
        io.out(CLI.encode(report))
        if !report.ok { io.err("afterglow run: \(report.refused) of \(plan.items.count) inputs refused, \(report.written) written") }
        return code
    }

    /// The session's document in the plan's format: a native save, or an export that must be one file.
    static func output(of session: HeadlessSession, plan: Plan) throws -> Data {
        if plan.format == plan.app.openExtensions.first { return try session.save() }
        let files = try session.export(plan.format, options: plan.script.output?.options ?? .object([:]))
        guard files.count == 1, let file = files.first else {
            throw CatalogError.failed(id: "export", message: "\(plan.format) writes \(files.count) files; a script output takes one")
        }
        return file.data
    }

    /// What a run prints: each input with its steps, outputs and why it stopped, and the counts.
    struct Report: Encodable {
        struct Input: Encodable { let input: String; var steps: [BatchReport.Step]; var outputs: [String]; var error: String? }
        var ok: Bool; var inputs: [Input]; var written: Int; var refused: Int
    }

    /// What a dry run prints: every input and the output it would write.
    struct DryRun: Encodable {
        struct Input: Encodable { let input: String; let outputs: [String] }
        var ok = true; var dryRun = true; let inputs: [Input]
    }
}
