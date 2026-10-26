// Arguments.swift (afterglow-cli CL-4): the strict parser. It reads one
// invocation into an `Invocation` before anything is read or written: the app
// and the command are checked against the registry first, then every flag
// must be one its form knows (else "unknown flag X"), no flag twice, and each
// operand present. A refusal here is usage (64), or data (65) for a `--json`
// that is not one JSON object.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One parsed invocation: the form and everything it names. A command's `output` is nil for `--in-place`.
enum Invocation {
    case version, help, listApps
    case listCommands(HeadlessApp), describe(HeadlessApp, command: String), open(HeadlessApp, file: String)
    case new(HeadlessApp, out: String, options: JSONValue, force: Bool)
    case command(HeadlessApp, step: CommandEnvelope, input: String, output: String?, force: Bool)
    case export(HeadlessApp, file: String, format: String, out: String, options: JSONValue, force: Bool)
    case script(String, dryRun: Bool, force: Bool), mcp([String])
}

/// The flags and operands that follow a form, read strictly: each of `values` takes the next token,
/// each of `switches` stands alone, and any other token starting with "-" is refused.
struct Flags {
    private var values: [String: String] = [:], switches: Set<String> = [], operands: [String] = []

    init(_ tokens: ArraySlice<String>, values valueFlags: Set<String> = [], switches switchFlags: Set<String> = []) throws(Refusal) {
        var rest = tokens
        while let token = rest.popFirst() {
            if valueFlags.contains(token) {
                guard let value = rest.popFirst() else { throw .usage("\(token) needs a value") }
                guard values.updateValue(value, forKey: token) == nil else { throw .usage("\(token) is given twice") }
            } else if switchFlags.contains(token) {
                guard switches.insert(token).inserted else { throw .usage("\(token) is given twice") }
            } else if token.hasPrefix("-") {
                throw .usage("unknown flag \(token)")
            } else {
                operands.append(token)
            }
        }
    }

    func has(_ flag: String) -> Bool { switches.contains(flag) }
    func value(_ flag: String) -> String? { values[flag] }
    func required(_ flag: String) throws(Refusal) -> String {
        if let value = values[flag] { value } else { throw .usage("missing \(flag) <file>") }
    }
    /// `--json`'s object, an empty object when it was not given.
    func json() throws(Refusal) -> JSONValue {
        guard let text = values["--json"] else { return .object([:]) }
        guard let value = try? JSONValue(json: Data(text.utf8)), case .object = value else {
            throw .data("--json is not one JSON object: \(text)")
        }
        return value
    }
    func none() throws(Refusal) { if let extra = operands.first { throw .usage("unexpected operand \(extra)") } }
    /// The one operand the form takes, called `name`.
    func only(_ name: String) throws(Refusal) -> String {
        guard let first = operands.first else { throw .usage("missing <\(name)>") }
        try Flags(operands.dropFirst()).none()
        return first
    }
}

enum Arguments {
    static let usage = """
    afterglow --version | --help | list-apps
    afterglow <app> list-commands | describe <command> | open <file>
    afterglow <app> new --out <file> [--json '{…}'] [--force]
    afterglow <app> <command> --in <file> (--out <file> | --in-place) [--json '{…}'] [--force]
    afterglow suite <command> --in <file> (--out <file> | --in-place) --bundle <AfterGlow.app> [--json '{…}'] [--force]
    afterglow <app> export <file> --format <fmt> --out <path> [--json '{options}'] [--force]
    afterglow run <script.jobs.json> [--dry-run] [--force]
    afterglow mcp [...]
    """

    /// Parses `arguments` (without the program name) against the apps in `apps`.
    static func parse(_ arguments: [String], apps: [HeadlessApp]) throws(Refusal) -> Invocation {
        guard let head = arguments.first else { throw .usage("afterglow needs a form; afterglow --help lists them") }
        let rest = arguments.dropFirst()
        switch head {
        case "--version": try Flags(rest).none(); return .version
        case "--help": try Flags(rest).none(); return .help
        case "list-apps": try Flags(rest).none(); return .listApps
        case "mcp": return .mcp(Array(rest))
        case "run":
            let flags = try Flags(rest, switches: ["--dry-run", "--force"])
            return .script(try flags.only("script.jobs.json"), dryRun: flags.has("--dry-run"), force: flags.has("--force"))
        default:
            if head.hasPrefix("-") { throw .usage("unknown flag \(head)") }
            guard let app = Apps.named(head, in: apps) else { throw .usage("unknown app \(head)") }
            return try parse(app: app, rest)
        }
    }

    static func parse(app: HeadlessApp, _ rest: ArraySlice<String>) throws(Refusal) -> Invocation {
        guard let form = rest.first else { throw .usage("afterglow \(app.name) needs a form or a command id") }
        let tail = rest.dropFirst()
        switch form {
        case "list-commands": try Flags(tail).none(); return .listCommands(app)
        case "describe":
            let id = try Flags(tail).only("command")
            try known(id, in: app)
            return .describe(app, command: id)
        case "open": return .open(app, file: try Flags(tail).only("file"))
        case "new":
            let flags = try Flags(tail, values: ["--out", "--json"], switches: ["--force"])
            try flags.none()
            return .new(app, out: try flags.required("--out"), options: try flags.json(), force: flags.has("--force"))
        case "export":
            let flags = try Flags(tail, values: ["--format", "--out", "--json"], switches: ["--force"])
            let file = try flags.only("file"), format = try flags.required("--format")
            guard app.exportFormats.contains(format) else {
                throw .usage("\(app.name) does not export \(format); it exports \(app.exportFormats.joined(separator: ", "))")
            }
            return .export(app, file: file, format: format, out: try flags.required("--out"), options: try flags.json(), force: flags.has("--force"))
        default:
            try known(form, in: app)
            let flags = try Flags(tail, values: ["--in", "--out", "--json", "--bundle"], switches: ["--in-place", "--force"])
            try flags.none()
            let app = try bundled(app, flags.value("--bundle"))
            let input = try flags.required("--in"), output = flags.value("--out")
            switch (output, flags.has("--in-place")) {
            case (nil, false): throw .usage("\(form) needs --out <file> or --in-place")
            case (.some, true): throw .usage("--out and --in-place can't go together")
            default: break
            }
            let step = CommandEnvelope(id: form, params: try flags.json())
            return .command(app, step: step, input: input, output: output, force: flags.has("--force"))
        }
    }

    /// `app`, or for `--bundle <path>` the suite's Help commands answering for that AfterGlow.app; any other app
    /// refuses the flag.
    static func bundled(_ app: HeadlessApp, _ bundle: String?) throws(Refusal) -> HeadlessApp {
        guard let bundle else { return app }
        guard app.name == Apps.suite.name else { throw .usage("--bundle is only for afterglow suite's commands, not \(app.name)'s") }
        return Apps.suite(bundle: bundle)
    }

    static func known(_ id: String, in app: HeadlessApp) throws(Refusal) {
        guard app.describeAll().contains(where: { $0.id == id }) else { throw .usage("unknown command \(id) for \(app.name)") }
    }
}
