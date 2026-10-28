// CLI.swift: the `afterglow` router (docs/blueprints/suite/features/afterglow-cli.md).
// CL-4 fills it: Arguments parses, the router runs the form over the registry
// through CLIIO, and Output prints one JSON object (plus a stderr line on
// failure). A refused run writes nothing: every check and the command run
// before the write, and `--in-place` refuses on a file the app only imports. `run` and `mcp` hand off to ScriptRunner and MCPServer.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum CLI {
    /// The tool's version, what `afterglow --version` prints.
    public static let version = "0.1.0"

    /// The sysexits codes the CLI answers with (BSD `sysexits`).
    public enum Exit {
        public static let ok: Int32 = 0
        public static let usage: Int32 = 64
        public static let data: Int32 = 65
        public static let unavailable: Int32 = 69
        public static let failed: Int32 = 70
        public static let cannotCreate: Int32 = 73
        public static let io: Int32 = 74
    }

    /// The apps the router knows: the five, the suite's Help commands, and the fakes (canvas, then tone), which the
    /// tests and the binary's journey drive.
    public static let registry = Apps.all + [Apps.suite, Apps.fake, Apps.fakeTone]

    /// Runs one invocation (`arguments` without the program name) over `io` among `apps`. Returns the exit code.
    public static func run(_ arguments: [String], apps: [HeadlessApp] = registry, io: any CLIIO) -> Int32 {
        do {
            switch try Arguments.parse(arguments, apps: apps) {
            case .script(let script, let dryRun, let force): return ScriptRunner.run(script, apps: apps, dryRun: dryRun, force: force, io: io)
            case .mcp(let rest): return MCPServer.serve(rest, apps: apps, io: io)
            case let invocation: return answer(try reply(to: invocation, apps: apps, io: io), io: io)
            }
        } catch {
            return refuse(error, io: io)
        }
    }

    /// Runs one invocation with no file system (every file reads as missing), printing through `out` and `err`.
    public static func run(_ arguments: [String], out: (String) -> Void, err: (String) -> Void) -> Int32 {
        let io = FakeIO()
        let code = run(arguments, io: io)
        io.stdout.forEach(out)
        io.stderr.forEach(err)
        return code
    }

    /// The reply fields for a single-shot form; throws what refuses it.
    static func reply(to invocation: Invocation, apps: [HeadlessApp], io: any CLIIO) throws -> [String: JSONValue] {
        switch invocation {
        case .version: return ["version": .string(version)]
        case .help: return ["usage": .string(Arguments.usage)]
        case .listApps:
            return ["apps": .array(apps.map { .object(["name": .string($0.name), "openExtensions": .array($0.openExtensions.map(JSONValue.string)),
                                                       "exportFormats": .array($0.exportFormats.map(JSONValue.string))]) })]
        case .listCommands(let app):
            let keep: Set = ["id", "kind", "summary", "title", "undoable"]
            let commands = try app.describeAll().map { description -> JSONValue in
                guard case .object(let fields) = try JSONValue(encoding: description) else { return .null }
                return .object(fields.filter { keep.contains($0.key) })
            }
            return ["app": .string(app.name), "commands": .array(commands)]
        case .describe(let app, let id):
            guard let description = app.describeAll().first(where: { $0.id == id }) else { throw Refusal.usage("unknown command \(id)") }
            return ["command": try JSONValue(encoding: description)]
        case .open(let app, let file): return ["summary": try open(file, as: app, io: io).summary()]
        case .new(let app, let out, let options, let force):
            try refuseExisting([out], force: force, io: io)
            let session = try app.session(new: options)
            try write(try session.save(), to: out, replace: force, io: io)
            return ["output": .string(out)]
        case .command(let app, let step, let input, let output, let force):
            var session = try open(input, as: app, io: io)
            let target = output ?? input
            if output == nil, !app.savesNatively(to: input), let native = app.openExtensions.first {
                throw Refusal.usage("--in-place would write a .\(native) over \(input); pass --out <file>.\(native)")
            }
            if output != nil { try refuseExisting([target], force: force, io: io) }
            if let why = session.availability(step.id).why { throw CatalogError.unavailable(id: step.id, why: why) }
            let outcome = try session.run(step)
            try write(try session.save(), to: target, replace: force || output == nil, io: io)
            return ["command": .string(step.id), "output": .string(target), "result": outcome.result,
                    "undoStep": outcome.undoStep.map(JSONValue.string) ?? .null]
        case .export(let app, let file, let format, let out, let options, let force):
            let files = try open(file, as: app, io: io).export(format, options: options)
            guard !files.isEmpty else { throw Refusal(code: Exit.failed, kind: "failed", message: "\(file) exported no files as \(format)") }
            let targets = files.count == 1 ? [out] : files.map { out + "/" + $0.suggestedName }
            try refuseExisting(targets, force: force, io: io)
            for (exported, target) in zip(files, targets) { try write(exported.data, to: target, replace: force, io: io) }
            return ["outputs": .array(targets.map(JSONValue.string))]
        case .script, .mcp: throw Refusal.usage("afterglow \(invocation) is not a single-shot form")
        }
    }

    /// Opens `file` as `app`'s document: missing is io (74), bytes the app can't read are data (65).
    static func open(_ file: String, as app: HeadlessApp, io: any CLIIO) throws -> HeadlessSession {
        let data: Data
        do { data = try io.read(file) } catch let error as CLIIOError { throw error } catch { throw Refusal.io("could not read \(file): \(error)") }
        do { return try app.session(open: data, name: file) } catch let error as CatalogError { throw error } catch {
            throw Refusal.data("\(file) is not a \(app.name) document: \(error)")
        }
    }

    /// Refuses (73) when any of `paths` exists and `force` is false.
    static func refuseExisting(_ paths: [String], force: Bool, io: any CLIIO) throws {
        if !force, let taken = paths.first(where: io.exists) { throw CLIIOError.exists(taken) }
    }

    /// Writes `data` to `path` through `io`; a failure other than an existing file is io (74).
    static func write(_ data: Data, to path: String, replace: Bool, io: any CLIIO) throws {
        do { try io.write(data, to: path, replace: replace) } catch let error as CLIIOError { throw error } catch {
            throw Refusal.io("could not write \(path): \(error)")
        }
    }

    struct Failure: Encodable {
        struct Body: Encodable { let kind: String; let message: String }
        var ok = false
        let error: Body
    }

    /// One JSON object on one line, keys sorted.
    static func encode(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else {
            return #"{"error":{"kind":"failed","message":"could not encode the reply"},"ok":false}"#
        }
        return text
    }
}
