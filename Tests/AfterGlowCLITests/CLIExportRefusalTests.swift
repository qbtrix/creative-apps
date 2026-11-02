// CLIExportRefusalTests.swift: export options the kernel refuses (quality gate #5834). A bad
// `--json` option is bad input: exit 65, kind "data", in words with no schema path, and a
// shape refusal names the CLI's own switch ("stretch": true), not the sheet's ratio lock.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AfterGlowCLICore
import Testing

struct CLIExportRefusalTests {
    /// Runs `fake export a.fake --format jpeg --json <options>` and returns its exit code and stdout reply.
    static func export(_ options: String) throws -> (code: Int32, reply: String) {
        let io = FakeIO(files: ["a.fake": try FakeCanvasDocument.fixture.save()])
        let code = CLI.run(["fake", "export", "a.fake", "--format", "jpeg", "--json", options, "--out", "a.jpg"], io: io)
        return (code, io.stdout.joined(separator: "\n"))
    }

    @Test(arguments: [
        #"{"size":{"pixels":[0,0]}}"#, #"{"size":{"pixels":[1080,1351]}}"#, #"{"colour":"red"}"#,
        #"{"quality":2}"#, #"{"size":{"scale":0}}"#,
    ])
    func aBadOptionIsData(_ options: String) throws {
        let (code, reply) = try Self.export(options)
        #expect(code == CLI.Exit.data)
        #expect(reply.contains(#""kind":"data""#))
        #expect(!reply.contains("/size") && !reply.contains("/colour") && !reply.contains("/quality"))
    }

    @Test func theShapeRefusalNamesStretch() throws {
        let (_, reply) = try Self.export(#"{"size":{"pixels":[1080,1351]}}"#)
        #expect(reply.contains(#"\"stretch\": true"#))
        #expect(!reply.contains("Unlock the ratio"))
    }

    @Test func aZeroSideSaysSoInWords() throws {
        let (_, reply) = try Self.export(#"{"size":{"pixels":[0,0]}}"#)
        #expect(reply.contains("at least 1"))
        #expect(!reply.contains("expected"))
    }
}
