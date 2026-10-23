// SampleMakerTests.swift (sample-files SS-2): the samples check on the repo,
// which scripts/ci runs with the rest of AfterGlowCLITests, and the maker's own
// cases on scratch roots with the CLI's fake app: an empty make folder passes,
// a stale or missing sample fails, write makes the check pass, a fixtures-only
// make file writes only the journey fixture, and the output is named after
// its make file. MAKE_SAMPLES=1 writes the repo's samples before checking them.
import AfterGlowCLICore
import Foundation
import Testing

@Suite struct SampleMakerTests {
    /// A make file for the fake app: one rect added to the seed.
    static let fakeScript = Data("""
    {"version": 1, "app": "fake", "inputs": ["seed.fake"],
     "steps": [{"id": "rect.add", "params": {"x": 1, "y": 2, "w": 3, "h": 4, "name": "Box"}}]}
    """.utf8)

    /// A fresh scratch root holding `files` (repo path -> bytes); the caller removes it.
    static func scratch(_ files: [String: Data]) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sample-maker-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent(SampleMaker.makeFolder), withIntermediateDirectories: true)
        for (path, data) in files {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        return root
    }

    @Test func committedSamplesMatchTheirMakeFiles() throws {
        let root = SampleOpenTests.root
        if ProcessInfo.processInfo.environment["MAKE_SAMPLES"] == "1" { try SampleMaker.write(root: root) }
        #expect(SampleMaker.check(root: root) == [])
    }

    @Test func emptyMakeFolderPasses() throws {
        let root = try Self.scratch([:])
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(SampleMaker.recipes(root: root).isEmpty)
        #expect(SampleMaker.check(root: root) == [])
    }

    @Test func staleSampleFailsUntilWritten() throws {
        let root = try Self.scratch(["Bundle/Samples/make/Box.fake.jobs.json": Self.fakeScript,
                                     "Bundle/Samples/Box.fake": Data("[]".utf8)])
        defer { try? FileManager.default.removeItem(at: root) }
        let problems = SampleMaker.check(root: root)
        #expect(problems.count == 1)
        #expect(problems.first?.hasPrefix("Bundle/Samples/Box.fake differs") == true)
        #expect(try SampleMaker.write(root: root) == ["Bundle/Samples/Box.fake", "UITests/Fixtures/suite/Box.fake"])
        #expect(SampleMaker.check(root: root) == [])
        // A stale fixture copy fails too, once it exists.
        try Data("[]".utf8).write(to: root.appendingPathComponent("UITests/Fixtures/suite/Box.fake"))
        #expect(SampleMaker.check(root: root).first?.hasPrefix("UITests/Fixtures/suite/Box.fake differs") == true)
    }

    @Test func missingSampleFails() throws {
        let root = try Self.scratch(["Bundle/Samples/make/Box.fake.jobs.json": Self.fakeScript])
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(SampleMaker.check(root: root).first?.hasPrefix("Bundle/Samples/Box.fake is missing") == true)
    }

    @Test func fixturesOnlyWritesOnlyTheFixture() throws {
        let root = try Self.scratch(["Bundle/Samples/make/fixtures-only/Logo.fake.jobs.json": Self.fakeScript])
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(SampleMaker.check(root: root).first?.hasPrefix("UITests/Fixtures/suite/Logo.fake is missing") == true)
        #expect(try SampleMaker.write(root: root) == ["UITests/Fixtures/suite/Logo.fake"])
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Bundle/Samples/Logo.fake").path))
        #expect(SampleMaker.check(root: root) == [])
    }

    @Test func sampleIsTheScriptRunOverANewSeed() throws {
        let root = try Self.scratch(["Bundle/Samples/make/Cards.fake.jobs.json": Self.fakeScript])
        defer { try? FileManager.default.removeItem(at: root) }
        let recipe = try #require(SampleMaker.recipes(root: root).first)
        #expect(recipe.name == "Cards.fake" && recipe.bundlePath == "Bundle/Samples/Cards.fake" && !recipe.fixtureOnly)
        let made = try SampleMaker.build(recipe, root: root)
        let session = try #require(Apps.named("fake", in: CLI.registry)).session(open: made, name: recipe.name)
        // The seed was empty; the script's one step added the rect.
        #expect(session.summary() == .object(["rects": .number(1), "selected": .null]))
    }

    @Test func brokenMakeFileIsAProblem() throws {
        let root = try Self.scratch(["Bundle/Samples/make/Bad.fake.jobs.json": Data(#"{"version": 1, "app": "nope", "inputs": ["seed.fake"], "steps": [{"id": "x", "params": {}}]}"#.utf8)])
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(SampleMaker.check(root: root).first?.contains("unknown app nope") == true)
    }
}
