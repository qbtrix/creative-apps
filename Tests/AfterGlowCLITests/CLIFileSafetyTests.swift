// CLIFileSafetyTests.swift: the CL-args file-safety checks (afterglow-cli
// CL-3, checks first; CL-5 turns them on). No form overwrites a file without
// `--force`; writing back to the input takes `--in-place`, never a default;
// a write is atomic, so a failed or replaced write leaves the target absent,
// as it was, or whole, and no temp file behind; a missing input or a
// directory is 74. Each check runs on FakeIO and on LiveIO, the real file
// system, in a temp directory. The router checks run once CL-4's router
// answers (`routed`); the LiveIO checks after them run now.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AfterGlowCLICore
import Testing

struct CLIFileSafetyTests {
    /// The fake fixture's bytes, `a.fake` on every disk.
    static let original = (try? FakeCanvasDocument.fixture.save()) ?? Data()
    static let addRect = #"{"x":5,"y":6,"w":7,"h":8}"#

    /// The real file system.
    static func liveIO() -> (any CLIIO)? { LiveIO() }

    /// Whether CL-4's router answers. Until it does, every form is a stub that exits 69, so the
    /// router checks are skipped by name rather than run against a stub.
    static let routed = CLI.run(["list-apps"], io: FakeIO()) != CLI.Exit.unavailable

    /// Where a check runs: the in-memory FakeIO, or LiveIO on a fresh temp directory.
    enum World: String, CaseIterable, Sendable { case fake, live }

    /// A disk holding some files by name, and how to look at it from outside the CLI.
    struct Disk {
        let io: any CLIIO
        /// The path the CLI takes for a file name, its bytes (nil when absent) and every name, sorted.
        let path: (String) -> String, bytes: (String) -> Data?, names: () -> [String]
        /// Runs `afterglow <arguments>` on this disk; the arguments already hold its paths.
        /// CL-4 routes this over the five apps plus the fake.
        func afterglow(_ arguments: [String]) -> Int32 { CLI.run(arguments, io: io) }
    }

    /// A disk in `world` holding `files`.
    static func disk(_ world: World, _ files: [String: Data] = ["a.fake": original]) throws -> Disk {
        switch world {
        case .fake:
            let io = FakeIO(files: files)
            return Disk(io: io, path: { $0 }, bytes: { io.files[$0] }, names: { io.files.keys.sorted() })
        case .live:
            let io = try #require(liveIO(), "LiveIO")
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("afterglow-\(UUID().uuidString)").path
            try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
            for (name, data) in files { _ = FileManager.default.createFile(atPath: root + "/" + name, contents: data) }
            return Disk(io: io, path: { root + "/" + $0 }, bytes: { FileManager.default.contents(atPath: root + "/" + $0) },
                        names: { ((try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []).sorted() })
        }
    }

    /// Each form that writes a file, aimed at `target` on `disk`.
    static func writers(_ disk: Disk, to target: String) -> [[String]] {
        let input = disk.path("a.fake"), out = disk.path(target)
        return [["fake", "rect.add", "--in", input, "--out", out, "--json", addRect],
                ["fake", "new", "--out", out],
                ["fake", "export", input, "--format", "json", "--out", out]]
    }

    @Test(.enabled(if: routed, "waits on CL-4's router"), arguments: World.allCases)
    func neverOverwrites(world: World) throws {
        let kept = Data("keep me".utf8)
        let disk = try Self.disk(world, ["a.fake": Self.original, "b.fake": kept])
        for form in Self.writers(disk, to: "b.fake") {
            #expect(disk.afterglow(form) == 73, "\(form) overwrote without --force")
            #expect(disk.bytes("b.fake") == kept)
        }
        #expect(disk.names() == ["a.fake", "b.fake"])
        // The protocol itself refuses too, whatever the router asks.
        #expect(throws: CLIIOError.exists(disk.path("b.fake"))) { try disk.io.write(Data(), to: disk.path("b.fake"), replace: false) }
        #expect(disk.bytes("b.fake") == kept)
    }

    @Test(.enabled(if: routed, "waits on CL-4's router"), arguments: World.allCases)
    func forceReplacesWhole(world: World) throws {
        let disk = try Self.disk(world, ["a.fake": Self.original, "b.fake": Data("old".utf8)])
        for form in Self.writers(disk, to: "b.fake") {
            #expect(disk.afterglow(form + ["--force"]) == 0, "\(form)")
            let bytes = try #require(disk.bytes("b.fake"))
            #expect(bytes != Data("old".utf8))
            #expect((try? JSONValue(json: bytes)) != nil, "\(form) left a partial file")
        }
        #expect(disk.names() == ["a.fake", "b.fake"], "a temp file was left behind")
    }

    @Test(.enabled(if: routed, "waits on CL-4's router"), arguments: World.allCases)
    func inPlaceIsExplicit(world: World) throws {
        let disk = try Self.disk(world)
        let input = disk.path("a.fake")
        #expect(disk.afterglow(["fake", "rect.add", "--in", input, "--json", Self.addRect]) == 64)
        #expect(disk.afterglow(["fake", "rect.add", "--in", input, "--force", "--json", Self.addRect]) == 64)
        #expect(disk.afterglow(["fake", "rect.add", "--in", input, "--out", input, "--json", Self.addRect]) == 73)
        #expect(disk.bytes("a.fake") == Self.original)
        #expect(disk.afterglow(["fake", "rect.add", "--in", input, "--in-place", "--json", Self.addRect]) == 0)
        let edited = try FakeCanvasDocument.open(try #require(disk.bytes("a.fake")), name: "a.fake")
        #expect(edited.rects.count == FakeCanvasDocument.fixture.rects.count + 1)
        #expect(disk.names() == ["a.fake"])
    }

    /// A disk whose every write fails, as a full disk does: the write throws before the target changes.
    struct FullDisk: CLIIO {
        struct NoSpace: Error {}
        let base: FakeIO
        func read(_ path: String) throws -> Data { try base.read(path) }
        func write(_ data: Data, to path: String, replace: Bool) throws { throw NoSpace() }
        func exists(_ path: String) -> Bool { base.exists(path) }
        func glob(_ pattern: String, relativeTo dir: String) throws -> [String] { try base.glob(pattern, relativeTo: dir) }
        func out(_ line: String) { base.out(line) }
        func err(_ line: String) { base.err(line) }
    }

    @Test(.enabled(if: routed, "waits on CL-4's router"))
    func atomicWrite() throws {
        // A write that fails is 74, prints one failure and leaves the target absent or as it was.
        let base = FakeIO(files: ["a.fake": Self.original, "b.fake": Data("old".utf8)])
        let full = FullDisk(base: base)
        #expect(CLI.run(["fake", "rect.add", "--in", "a.fake", "--out", "c.fake", "--json", Self.addRect], io: full) == 74)
        #expect(CLI.run(["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--force", "--json", Self.addRect], io: full) == 74)
        #expect(base.files == ["a.fake": Self.original, "b.fake": Data("old".utf8)])
        #expect(base.stdout.count == 2)
        #expect(base.stdout.allSatisfy { $0.contains(#""kind":"io""#) && $0.hasSuffix(#""ok":false}"#) })

        // On disk the new bytes arrive by rename: another link to the old file keeps the old bytes whole,
        // where a write straight into the target would change both.
        let disk = try Self.disk(.live, ["a.fake": Self.original, "b.fake": Data("old".utf8)])
        try FileManager.default.linkItem(atPath: disk.path("b.fake"), toPath: disk.path("twin.fake"))
        #expect(disk.afterglow(["fake", "rect.add", "--in", disk.path("a.fake"), "--out", disk.path("b.fake"),
                                "--force", "--json", Self.addRect]) == 0)
        #expect(disk.bytes("twin.fake") == Data("old".utf8))
        #expect(disk.bytes("b.fake").flatMap { try? FakeCanvasDocument.open($0, name: "b.fake") }?.rects.count == 3)

        // A write that can't land (its folder is a file) is 74 and leaves the folder as it was.
        #expect(disk.afterglow(["fake", "new", "--out", disk.path("a.fake") + "/c.fake"]) == 74)
        #expect(disk.names() == ["a.fake", "b.fake", "twin.fake"])
        #expect(disk.bytes("a.fake") == Self.original)
    }

    @Test(.enabled(if: routed, "waits on CL-4's router"), arguments: World.allCases)
    func missingInputIs74(world: World) throws {
        let disk = try Self.disk(world)
        let missing = disk.path("missing.fake")
        #expect(disk.afterglow(["fake", "open", missing]) == 74)
        #expect(disk.afterglow(["fake", "rect.add", "--in", missing, "--out", disk.path("b.fake"), "--json", Self.addRect]) == 74)
        #expect(disk.afterglow(["fake", "export", missing, "--format", "json", "--out", disk.path("b.json")]) == 74)
        #expect(throws: (any Error).self) { try disk.io.read(missing) }
        #expect(disk.names() == ["a.fake"])
    }

    @Test(.enabled(if: routed, "waits on CL-4's router"))
    func directoryIs74() throws {
        let disk = try Self.disk(.live)
        let folder = disk.path("folder.fake")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try disk.io.read(folder) }
        #expect(disk.afterglow(["fake", "open", folder]) == 74)
        #expect(disk.afterglow(["fake", "rect.add", "--in", folder, "--out", disk.path("b.fake"), "--json", Self.addRect]) == 74)
        // A directory where the output goes is never replaced, even with --force.
        #expect(disk.afterglow(["fake", "new", "--out", folder, "--force"]) == 74)
        #expect((try? FileManager.default.contentsOfDirectory(atPath: folder)) != nil, "the folder is gone")
        #expect(disk.names() == ["a.fake", "folder.fake"])
    }
}

/// LiveIO itself, below the router: the same promises on the real file system.
extension CLIFileSafetyTests {
    /// LiveIO and a fresh temp directory holding `files`, with that directory's path.
    static func live(_ files: [String: Data]) throws -> (io: LiveIO, disk: Disk, root: String) {
        let disk = try disk(.live, files)
        return (LiveIO(), disk, String(disk.path("x").dropLast(2)))
    }

    @Test func liveNeverOverwrites() throws {
        let kept = Data("keep me".utf8)
        let (io, disk, _) = try Self.live(["b.fake": kept])
        #expect(throws: CLIIOError.exists(disk.path("b.fake"))) {
            try io.write(Data("new".utf8), to: disk.path("b.fake"), replace: false)
        }
        #expect(disk.bytes("b.fake") == kept)
        try io.write(Data("new".utf8), to: disk.path("c.fake"), replace: false)
        #expect(disk.bytes("c.fake") == Data("new".utf8))
        #expect(disk.names() == ["b.fake", "c.fake"], "a temp file was left behind")
    }

    @Test func liveAtomicWrite() throws {
        let (io, disk, _) = try Self.live(["b.fake": Data("old".utf8)])
        try FileManager.default.linkItem(atPath: disk.path("b.fake"), toPath: disk.path("twin.fake"))
        try io.write(Data("new".utf8), to: disk.path("b.fake"), replace: true)
        #expect(disk.bytes("b.fake") == Data("new".utf8))
        #expect(disk.bytes("twin.fake") == Data("old".utf8), "the write went straight into the target")
        #expect(disk.names() == ["b.fake", "twin.fake"], "a temp file was left behind")
        // A folder that is a file, and a directory as the target, refuse and change nothing.
        #expect(throws: (any Error).self) { try io.write(Data("x".utf8), to: disk.path("b.fake") + "/c.fake", replace: true) }
        try FileManager.default.createDirectory(atPath: disk.path("folder"), withIntermediateDirectories: false)
        #expect(throws: LiveIOError.notAFile(disk.path("folder"))) {
            try io.write(Data("x".utf8), to: disk.path("folder"), replace: true)
        }
        #expect(io.exists(disk.path("folder")))
        #expect(disk.names() == ["b.fake", "folder", "twin.fake"])
        #expect(disk.bytes("b.fake") == Data("new".utf8))
    }

    /// A write into folders that don't exist yet makes them (a batch's `out/`), and only them.
    @Test func liveWriteMakesFolders() throws {
        let (io, disk, _) = try Self.live([:])
        try io.write(Data("new".utf8), to: disk.path("out/deep/c.fake"), replace: false)
        #expect(disk.bytes("out/deep/c.fake") == Data("new".utf8))
        #expect(disk.names() == ["out"])
        #expect((try? FileManager.default.contentsOfDirectory(atPath: disk.path("out/deep"))) == ["c.fake"])
    }

    @Test func liveReadRefuses() throws {
        let (io, disk, _) = try Self.live(["a.fake": Self.original, "big.fake": Data(count: 9)])
        #expect(try io.read(disk.path("a.fake")) == Self.original)
        #expect(throws: CLIIOError.missing(disk.path("missing.fake"))) { try io.read(disk.path("missing.fake")) }
        try FileManager.default.createDirectory(atPath: disk.path("folder"), withIntermediateDirectories: false)
        #expect(throws: LiveIOError.notAFile(disk.path("folder"))) { try io.read(disk.path("folder")) }
        #expect(LiveIO.defaultReadLimit == 2 * 1024 * 1024 * 1024)
        #expect(throws: LiveIOError.tooLarge(disk.path("big.fake"), 9)) { try LiveIO(readLimit: 8).read(disk.path("big.fake")) }
        #expect(try LiveIO(readLimit: 9).read(disk.path("big.fake")).count == 9)
    }

    @Test func liveGlobWithoutAShell() throws {
        let none = Data()
        let (io, disk, root) = try Self.live(["b.fake": none, "a.fake": none, "c.txt": none, ".hidden.fake": none,
                                              "$(touch x).fake": none])
        try FileManager.default.createDirectory(atPath: disk.path("sub"), withIntermediateDirectories: false)
        try FileManager.default.createDirectory(atPath: disk.path("dir.fake"), withIntermediateDirectories: false)
        _ = FileManager.default.createFile(atPath: disk.path("sub/d.fake"), contents: none)
        #expect(try io.glob("*.fake", relativeTo: root) == ["$(touch x).fake", "a.fake", "b.fake"].map(disk.path))
        #expect(try io.glob("*.fake", relativeTo: root + "/") == ["$(touch x).fake", "a.fake", "b.fake"].map(disk.path))
        #expect(try io.glob("?.txt", relativeTo: root) == [disk.path("c.txt")])
        #expect(try io.glob("*/d.fake", relativeTo: root) == [disk.path("sub/d.fake")])
        #expect(try io.glob(disk.path("sub/*"), relativeTo: "/elsewhere") == [disk.path("sub/d.fake")])
        #expect(try io.glob(".*.fake", relativeTo: root) == [disk.path(".hidden.fake")])
        #expect(try io.glob("missing/*.fake", relativeTo: root).isEmpty)
        #expect(!io.exists(disk.path("x")), "a pattern reached a shell")
    }

    @Test func sessionsReadThroughIO() throws {
        let (io, disk, _) = try Self.live(["a.fake": Self.original])
        let session = try Apps.fake.session(reading: disk.path("a.fake"), io: io)
        #expect(session.app == "fake")
        #expect(throws: CLIIOError.missing(disk.path("none.fake"))) {
            try Apps.fake.session(reading: disk.path("none.fake"), io: io)
        }
    }
}
