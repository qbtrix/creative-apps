// Output.swift (afterglow-cli CL-4): one JSON object per run, keys sorted,
// `{"ok":true,...}` or `{"ok":false,"error":{kind,message,issues?}}`, plus one
// stderr line on failure. `Refusal` maps each error to its sysexits code:
// usage 64, data 65 (a refused export option among them), unavailable/notBuilt 69, failed 70, exists 73, io 74.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Why an invocation stopped: its exit code, error kind and message, and the schema issues when params failed.
struct Refusal: Error {
    let code: Int32, kind: String, message: String
    var issues: [SchemaIssue] = []

    static func usage(_ message: String) -> Refusal { Refusal(code: CLI.Exit.usage, kind: "usage", message: message) }
    static func data(_ message: String) -> Refusal { Refusal(code: CLI.Exit.data, kind: "data", message: message) }
    static func io(_ message: String) -> Refusal { Refusal(code: CLI.Exit.io, kind: "io", message: message) }

    /// The `{"ok": false, "error": …}` object.
    var reply: JSONValue {
        var body: [String: JSONValue] = ["kind": .string(kind), "message": .string(message)]
        if !issues.isEmpty, let list = try? JSONValue(encoding: issues) { body["issues"] = list }
        return .object(["ok": .bool(false), "error": .object(body)])
    }
}

extension Refusal {
    /// The refusal `error` maps to; an error nothing names is `failed` (70).
    init(_ error: any Error) {
        switch error {
        case let refusal as Refusal: self = refusal
        case let error as CatalogError: self.init(catalog: error)
        case let error as ExportOptionRefusal:
            self = .data(String(describing: error).replacing(ExportRules.unlockHint, with: ExportRules.stretchHint))
        case CLIIOError.missing(let path): self = .io("there is no file at \(path)")
        case CLIIOError.exists(let path):
            self.init(code: CLI.Exit.cannotCreate, kind: "exists", message: "\(path) already exists; pass --force to replace it")
        default: self.init(code: CLI.Exit.failed, kind: "failed", message: "\(error)")
        }
    }

    /// The refusal a catalog's error maps to: unavailable carries the app's own why-not.
    init(catalog error: CatalogError) {
        switch error {
        case .unknownCommand(let id): self = .usage("unknown command \(id)")
        case .malformedParams(let id, let issues):
            let found = issues.map { "\($0.path.isEmpty ? "/" : $0.path) \($0.message)" }.joined(separator: "; ")
            self.init(code: CLI.Exit.data, kind: "data", message: "\(id) params don't match its schema: \(found)", issues: issues)
        case .unavailable(_, let why): self.init(code: CLI.Exit.unavailable, kind: "unavailable", message: why)
        case .notBuilt(let id, let feature): self.init(code: CLI.Exit.unavailable, kind: "notBuilt", message: "\(id) is not built yet (\(feature))")
        case .failed(_, let message): self.init(code: CLI.Exit.failed, kind: "failed", message: message)
        }
    }
}

extension CLI {
    /// Prints a successful run's reply, `fields` plus `"ok": true`, and returns 0.
    static func answer(_ fields: [String: JSONValue], io: any CLIIO) -> Int32 {
        io.out(encode(JSONValue.object(fields.merging(["ok": .bool(true)]) { _, ok in ok })))
        return Exit.ok
    }

    /// Prints the failure for `error` on stdout and its message on stderr, and returns its exit code.
    static func refuse(_ error: any Error, io: any CLIIO) -> Int32 {
        let refusal = Refusal(error)
        io.out(encode(refusal.reply))
        io.err(refusal.message)
        return refusal.code
    }
}
