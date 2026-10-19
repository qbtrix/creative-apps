// CLI.swift: the `afterglow` router (docs/blueprints/suite/features/afterglow-cli.md).
// CL-1 declares it with `--version` live; every other form is a stub that
// exits 69 (`unavailable`, kind `notBuilt`) naming the slice that builds it.
// CL-2 adds `run(_:io:)` over CLIIO, which forwards here; CL-4 fills the
// parser and the routes. Output is exactly one JSON object on stdout per
// invocation, keys sorted, plus one human line on stderr when `ok` is false.
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

    /// Runs one invocation: `arguments` without the program name. `out`
    /// gets the one JSON line for stdout, `err` the human line for stderr.
    /// Returns the exit code.
    public static func run(_ arguments: [String], out: (String) -> Void, err: (String) -> Void) -> Int32 {
        if arguments == ["--version"] {
            out(encode(VersionReply(version: version)))
            return Exit.ok
        }
        let slice = Self.slice(for: arguments)
        let message = "afterglow \(arguments.joined(separator: " ")) is not built yet (slice \(slice))"
        out(encode(Failure(error: .init(kind: "notBuilt", message: message))))
        err(message)
        return Exit.unavailable
    }

    /// The slice of the packet that builds this form.
    static func slice(for arguments: [String]) -> String {
        switch arguments.first {
        case "run": "CL-batch"
        case "mcp": "afterglow-mcp"
        default: "CL-args"
        }
    }

    struct VersionReply: Encodable { let version: String }

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
