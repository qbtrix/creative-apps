// CLIShapeTests.swift: LJ0's first half (afterglow-cli CL-1). `afterglow
// --version` prints exactly one JSON object with sorted keys and exits 0;
// since CL-4 the other single-shot forms answer (CLIArgsTests), and `run`
// and `mcp` are stubs that exit 69 naming their slice. Runs
// through CLI.run, the same entry main.swift calls, so both targets build
// on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AfterGlowCLICore
import Testing

struct CLIShapeTests {
    /// One run's exit code and the lines it wrote to stdout and stderr.
    struct Run { let code: Int32; let out: [String]; let err: [String] }

    static func run(_ arguments: [String]) -> Run {
        var out: [String] = [], err: [String] = []
        let code = CLI.run(arguments, out: { out.append($0) }, err: { err.append($0) })
        return Run(code: code, out: out, err: err)
    }

    static func object(_ line: String) -> [String: JSONValueish]? {
        try? JSONDecoder().decode([String: JSONValueish].self, from: Data(line.utf8))
    }

    @Test func versionPrintsOneJSONObjectAndExitsZero() {
        let run = Self.run(["--version"])
        #expect(run.code == 0)
        #expect(run.out == [#"{"ok":true,"version":"\#(CLI.version)"}"#])
        #expect(run.err.isEmpty)
        #expect(Self.object(run.out.first ?? "")?["version"] == .string(CLI.version))
        #expect(!CLI.version.isEmpty)
    }

    @Test(arguments: [(["run", "resize.jobs.json"], "slice CL-batch"), (["mcp"], "afterglow-mcp is not built yet")])
    func everyOtherFormIsAStubThatNamesItsSlice(arguments: [String], slice: String) {
        let run = Self.run(arguments)
        #expect(run.code == 69)
        #expect(run.out.count == 1)
        let line = run.out.first ?? ""
        #expect(line.hasPrefix(#"{"error":{"kind":"notBuilt","message":"#), "keys are not sorted: \(line)")
        #expect(line.hasSuffix(#""ok":false}"#))
        #expect(Self.object(line)?["ok"] == .bool(false))
        #expect(run.err.count == 1)
        #expect(run.err.first?.contains(slice) == true, "\(run.err)")
    }
}

/// The scalar JSON this suite reads back (CL-2 brings SuiteKernel's JSONValue).
enum JSONValueish: Decodable, Equatable {
    case string(String), bool(Bool), object([String: JSONValueish])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let flag = try? container.decode(Bool.self) {
            self = .bool(flag)
        } else if let text = try? container.decode(String.self) {
            self = .string(text)
        } else {
            self = .object(try container.decode([String: JSONValueish].self))
        }
    }
}
