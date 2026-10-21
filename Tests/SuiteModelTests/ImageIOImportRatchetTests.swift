// ImageIOImportRatchetTests.swift (shared-codecs SC-1, rule 20): one ImageIO adapter. A `.swift` file under
// `Sources/` may import ImageIO only if it is `Sources/SuiteShell/SuiteImageIO.swift` or is listed in
// `Tests/imageio-baseline.txt`. The baseline only shrinks: its line count is capped at today's nine, a listed
// file that no longer imports ImageIO passes, and SC-12 deletes the file so the adapter is the only one left.
// The scan takes a root, so a test runs it on a temporary tree with a fixture import in HaloModel.
import Foundation
import Testing

enum ImageIOImportScan {
    /// The module the ratchet keeps in one file (split so this file's own text never reads as an import).
    static let module = "Image" + "IO"
    /// The one file allowed to import it.
    static let adapter = "Sources/SuiteShell/SuiteImageIO.swift"
    /// The kinds a scoped import may name (`import struct ImageIO.X`).
    static let kinds: Set<Substring> = ["typealias", "struct", "class", "enum", "protocol", "let", "var", "func"]

    /// True when a line of `text` imports the module: attributes and `@_exported` allowed, plain or scoped.
    static func imports(_ text: String) -> Bool {
        text.split(separator: "\n", omittingEmptySubsequences: true).contains { line in
            var words = line.split(whereSeparator: { $0 == " " || $0 == "\t" })[...]
            while let first = words.first, first.hasPrefix("@") { words = words.dropFirst() }
            guard words.first == "import" else { return false }
            words = words.dropFirst()
            if let kind = words.first, kinds.contains(kind) { words = words.dropFirst() }
            guard let name = words.first else { return false }
            return name == module || name.hasPrefix(module + ".")
        }
    }

    /// The baseline's paths: one per line, blank lines and `#` comments skipped.
    static func listed(_ baseline: String) -> [String] {
        baseline.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// Every `.swift` under `root/Sources` that imports the module, by path relative to `root`, sorted.
    static func importers(root: URL) throws -> [String] {
        let sources = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else { return [] }
        var hits: [String] = []
        while let path = walker.nextObject() as? String {
            guard path.hasSuffix(".swift") else { continue }
            if imports(try String(contentsOf: sources.appendingPathComponent(path), encoding: .utf8)) {
                hits.append("Sources/" + path)
            }
        }
        return hits.sorted()
    }

    /// One message per importer under `root` that is neither the adapter nor in `baseline`.
    static func problems(root: URL, baseline: String) throws -> [String] {
        let allowed = Set(listed(baseline)).union([adapter])
        return try importers(root: root).filter { !allowed.contains($0) }
            .map { "\($0) imports \(module); call SuiteImageIO (\(adapter)) instead" }
    }
}

@Suite struct ImageIOImportRatchetTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static func baseline() throws -> String {
        try String(contentsOf: root.appendingPathComponent("Tests/imageio-baseline.txt"), encoding: .utf8)
    }
    static let line = "import " + ImageIOImportScan.module

    /// A temporary tree holding `files` (path relative to the tree to text), removed after `body`.
    static func withTree<T>(_ files: [String: String], _ body: (URL) throws -> T) throws -> T {
        let tree = FileManager.default.temporaryDirectory.appendingPathComponent("imageio-ratchet-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tree) }
        for (path, text) in files {
            let url = tree.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return try body(tree)
    }

    /// Today's tree passes against the baseline, and the baseline names files that import it today.
    @Test func realTreePasses() throws {
        let problems = try ImageIOImportScan.problems(root: Self.root, baseline: try Self.baseline())
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
        #expect(!(try ImageIOImportScan.importers(root: Self.root)).isEmpty)
    }

    /// The baseline only shrinks: never more than today's nine lines, and no line twice.
    @Test func baselineOnlyShrinks() throws {
        let listed = ImageIOImportScan.listed(try Self.baseline())
        #expect(listed.count <= 9)
        #expect(Set(listed).count == listed.count)
    }

    /// A new importer fails: a fixture import in HaloModel, on a temporary tree, with today's baseline, while
    /// the adapter and a listed file pass beside it.
    @Test func fixtureImportInHaloModelFails() throws {
        let files = ["Sources/HaloModel/HaloFixture.swift": "import Foundation\n\(Self.line)\n",
                     ImageIOImportScan.adapter: "\(Self.line)\n",
                     "Sources/PhotoApp/ImageIOCodec.swift": "\(Self.line)\n"]
        let problems = try Self.withTree(files) { try ImageIOImportScan.problems(root: $0, baseline: try Self.baseline()) }
        #expect(problems == ["Sources/HaloModel/HaloFixture.swift imports ImageIO; call SuiteImageIO (\(ImageIOImportScan.adapter)) instead"])
    }

    /// Attributed, scoped and indented imports count; a comment, a longer module name or a string don't.
    @Test func importForms() {
        let module = ImageIOImportScan.module
        for text in ["@preconcurrency import \(module)", "  import struct \(module).CGImageSource",
                     "#if canImport(\(module))\nimport \(module) // decode\n#endif", "@_exported import \(module)"] {
            #expect(ImageIOImportScan.imports(text), "\(text)")
        }
        for text in ["// import \(module)", "import \(module)Kit", "let s = \"import \(module)\"", "import Foundation"] {
            #expect(!ImageIOImportScan.imports(text), "\(text)")
        }
    }

    /// A listed file with no import passes, so a slice can move the code before it drops the line.
    @Test func listedFileWithoutImportPasses() throws {
        let files = ["Sources/PhotoApp/ImageIOCodec.swift": "import Foundation\n"]
        let problems = try Self.withTree(files) {
            try ImageIOImportScan.problems(root: $0, baseline: "# c\nSources/PhotoApp/ImageIOCodec.swift\n")
        }
        #expect(problems.isEmpty)
    }
}
