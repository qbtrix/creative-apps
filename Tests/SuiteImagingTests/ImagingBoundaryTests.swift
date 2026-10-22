// ImagingBoundaryTests.swift: only SuiteImaging touches Metal (suite-imaging
// IM-1, slice IM-a, journey MJ-IM). Two rules, read from the tree as text:
//
//   1. a Swift file under Sources/ that imports Metal, MetalKit,
//      MetalPerformanceShaders or CoreRenderMetal must sit in
//      Sources/SuiteImaging/ (that folder, not a sibling that shares its
//      prefix) or be one of SuiteUI's canvas host files, by name;
//   2. every "CoreRenderMetal" product Package.swift names must belong to
//      SuiteImaging's macOS dependencies (`imagingMetal`) or the
//      AppSnapshotTests test target.
//
// Tests/metal-boundary-baseline.txt grandfathers what predates the rule:
// Photo's three canvas files and `appEngines["Photo"]`. It only shrinks: a
// listed entry that no longer occurs fails too, so a fix deletes its line.
// IM-8 moves Photo's files off it; IM-13 deletes it and appEngines["Photo"].
import Foundation
import Testing
import SuiteImaging

enum ImagingBoundary {
    static let metalModules = ["Metal", "MetalKit", "MetalPerformanceShaders", "CoreRenderMetal"]
    /// The one folder whose files may import Metal. The trailing slash keeps
    /// a sibling such as Sources/SuiteImagingX/ out.
    static let imagingFolder = "Sources/SuiteImaging/"
    /// SuiteUI's canvas host presents textures and runs no imaging, so it is allowed by name.
    static let canvasHost: Set<String> = ["Sources/SuiteUI/CanvasHostView+Metal.swift", "Sources/SuiteUI/CanvasTilePresenter.swift"]
    /// The Package.swift owners that may name CoreRenderMetal.
    static let packageOwners: Set<String> = ["imagingMetal", "AppSnapshotTests"]

    static func allowsMetal(_ path: String) -> Bool {
        path.hasPrefix(imagingFolder) || canvasHost.contains(path)
    }

    /// Whether one source line imports a Metal module (`import Metal`,
    /// `@preconcurrency import MetalKit`, `import struct Metal.MTLSize`).
    static func importsMetal(_ line: Substring) -> Bool {
        var words = line.split(whereSeparator: { $0 == " " || $0 == "\t" })[...]
        while let first = words.first, first.hasPrefix("@") { words = words.dropFirst() }
        guard words.first == "import" else { return false }
        words = words.dropFirst()
        let kinds: Set<Substring> = ["typealias", "struct", "class", "enum", "protocol", "let", "var", "func"]
        if let kind = words.first, kinds.contains(kind) { words = words.dropFirst() }
        guard let module = words.first?.split(separator: ".").first else { return false }
        return metalModules.contains(String(module))
    }

    /// The files (path relative to the repo, Sources/...) that import a Metal module.
    static func importHits(_ files: [String: String]) -> Set<String> {
        Set(files.compactMap { path, text in
            text.split(separator: "\n").contains(where: importsMetal) ? path : nil
        })
    }

    /// A line without its `//` comment (a `//` after `:` is a URL, not a comment).
    static func code(_ line: Substring) -> Substring {
        var previous: Character = " "
        var index = line.startIndex
        while index < line.endIndex {
            let next = line.index(after: index)
            if line[index] == "/", next < line.endIndex, line[next] == "/", previous != ":" {
                return line[..<index]
            }
            previous = line[index]
            index = next
        }
        return line
    }

    /// The owner of each "CoreRenderMetal" product the manifest names: the
    /// `let` or `var` it is declared in (`appEngines["Photo"]` for a
    /// dictionary entry), the `model("X", ...)` call (XModel), or the
    /// nearest `name: "X"` before it (a target), else `?`.
    static func packageOwners(_ manifest: String) -> [String] {
        let lines = manifest.split(separator: "\n", omittingEmptySubsequences: false).map(code)
        var owners: [String] = []
        for (row, line) in lines.enumerated() {
            var rest = line[...]
            while let mention = rest.range(of: "\"CoreRenderMetal\"") {
                let before = line[line.startIndex..<mention.lowerBound]
                owners.append(owner(before: before, earlier: lines[..<row]))
                rest = line[mention.upperBound...]
            }
        }
        return owners
    }

    static func owner(before: Substring, earlier: ArraySlice<Substring>) -> String {
        if let declared = before.firstMatch(of: /^\s*(?:let|var)\s+(\w+)[^=]*=(.*)$/) {
            if let key = declared.output.2.firstMatch(of: /"(\w+)"\s*:/) {
                return "\(declared.output.1)[\"\(key.output.1)\"]"
            }
            return String(declared.output.1)
        }
        if let call = before.firstMatch(of: /model\("(\w+)"/) { return "\(call.output.1)Model" }
        for text in [before] + earlier.reversed() {
            let names = text.matches(of: /name:\s*"(\w+)"/).map { String($0.output.1) }.filter { $0 != "CoreRenderMetal" }
            if let name = names.last { return name }
        }
        return "?"
    }

    /// The manifest's CoreRenderMetal links outside the allowed owners, as baseline keys.
    static func packageHits(_ manifest: String) -> Set<String> {
        Set(packageOwners(manifest).filter { !packageOwners.contains($0) }.map { "Package.swift: \($0)" })
    }

    static func listed(_ hit: String, in baseline: Set<String>) -> Bool {
        baseline.contains(hit)
    }

    /// The hits the baseline doesn't list, and the baseline lines nothing hits (stale).
    static func check(files: [String: String], manifest: String, baseline: Set<String>) -> (new: [String], stale: [String]) {
        let hits = importHits(files).filter { !allowsMetal($0) }.union(packageHits(manifest))
        return (hits.filter { !listed($0, in: baseline) }.sorted(), baseline.subtracting(hits).sorted())
    }

    /// The baseline's entries: one per line, `#` starts a comment.
    static func baseline(_ text: String) -> Set<String> {
        Set(text.split(separator: "\n").compactMap { line in
            let entry = (line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
                .trimmingCharacters(in: .whitespaces)
            return entry.isEmpty ? nil : entry
        })
    }
}

@Suite struct ImagingBoundaryTests {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func read(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Every Swift file under Sources/, keyed by its path from the repo root.
    static func sourceTree() throws -> [String: String] {
        let sources = root.appendingPathComponent("Sources")
        var files: [String: String] = [:]
        let walk = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        while let url = walk?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let path = "Sources/" + url.path.dropFirst(sources.path.count + 1)
            files[path] = try String(contentsOf: url, encoding: .utf8)
        }
        return files
    }

    static let manifest = """
        let imagingMetal: [Target.Dependency] = [.product(name: "CoreRenderMetal", package: core)]
        """

    @Test func theNamespaceExists() {
        #expect(SuiteImaging.version >= 1)
    }

    @Test func aMetalImportOutsideSuiteImagingFails() {
        let files = ["Sources/DesignApp/X.swift": "import SwiftUI\nimport Metal\n",
                     "Sources/SuiteImaging/Y.swift": "#if canImport(Metal)\nimport Metal\n#endif\n",
                     "Sources/SuiteUI/CanvasTilePresenter.swift": "@preconcurrency import MetalKit\n",
                     "Sources/PhotoModel/Z.swift": "import CoreRender // not Metal\nlet metal = \"import Metal\"\n"]
        let result = ImagingBoundary.check(files: files, manifest: Self.manifest, baseline: [])
        #expect(result.new == ["Sources/DesignApp/X.swift"])
        #expect(result.stale.isEmpty)
        for line in ["import CoreRenderMetal", "import struct Metal.MTLSize", "  @testable import MetalPerformanceShaders"] {
            #expect(ImagingBoundary.importsMetal(line[...]), "\(line)")
        }
        for line in ["import MetalFXLike", "// import Metal", "import CoreRender"] {
            #expect(!ImagingBoundary.importsMetal(line[...]), "\(line)")
        }
    }

    @Test func exactFolder() {
        let files = ["Sources/SuiteImagingX/X.swift": "import Metal\n", "Sources/SuiteImaging/Route/Y.swift": "import Metal\n"]
        #expect(ImagingBoundary.check(files: files, manifest: "", baseline: []).new == ["Sources/SuiteImagingX/X.swift"])
        #expect(!ImagingBoundary.allowsMetal("Sources/SuiteImagingTools/Z.swift"))
        #expect(!ImagingBoundary.allowsMetal("Sources/SuiteUI/CanvasHostView+MetalExtra.swift"))
        #expect(ImagingBoundary.allowsMetal("Sources/SuiteImaging/SuiteImaging.swift"))
    }

    @Test func baselineOnlyListed() {
        let files = ["Sources/PhotoApp/TileCanvas.swift": "import Metal\n", "Sources/DesignApp/X.swift": "import Metal\n"]
        let baseline: Set = ["Sources/PhotoApp/TileCanvas.swift"]
        let result = ImagingBoundary.check(files: files, manifest: "", baseline: baseline)
        #expect(result.new == ["Sources/DesignApp/X.swift"])
        #expect(result.stale.isEmpty)
        // Shrink-only: a listed file that no longer imports Metal is stale.
        let fixed = ImagingBoundary.check(files: ["Sources/PhotoApp/TileCanvas.swift": "import CoreRender\n"], manifest: "", baseline: baseline)
        #expect(fixed.new.isEmpty && fixed.stale == ["Sources/PhotoApp/TileCanvas.swift"])
    }

    @Test func aCoreRenderMetalLinkOutsideSuiteImagingFails() {
        let manifest = """
            let imagingMetal: [Target.Dependency] = [.product(name: "CoreRenderMetal", package: core)] // macOS only
            .package(url: "https://github.com/qbtrix/creative-core", revision: "x"),
            + model("Design", ["CoreColor", "CoreRenderMetal"])
            .testTarget(
                name: "AppSnapshotTests",
                dependencies: ["SuiteUI", .product(name: "CoreRenderMetal", package: core)]
            ),
            let appEngines: [String: [Target.Dependency]] = ["Photo": [.product(name: "CoreRenderMetal", package: core)]]
            .target(name: "HaloModel", dependencies: [.product(name: "CoreRenderMetal", package: core)]),
            // a comment naming "CoreRenderMetal" links nothing
            """
        #expect(ImagingBoundary.packageOwners(manifest) == ["imagingMetal", "DesignModel", "AppSnapshotTests", "appEngines[\"Photo\"]", "HaloModel"])
        let result = ImagingBoundary.check(files: [:], manifest: manifest, baseline: ["Package.swift: appEngines[\"Photo\"]"])
        #expect(result.new == ["Package.swift: DesignModel", "Package.swift: HaloModel"])
        #expect(result.stale.isEmpty)
    }

    @Test func theTreePassesWithTheBaseline() throws {
        let baseline = ImagingBoundary.baseline(try Self.read("Tests/metal-boundary-baseline.txt"))
        #expect(baseline.count == 4)
        let files = try Self.sourceTree()
        #expect(files.count > 100 && files["Sources/SuiteImaging/SuiteImaging.swift"] != nil)
        let result = ImagingBoundary.check(files: files, manifest: try Self.read("Package.swift"), baseline: baseline)
        #expect(result.new == [], "import Metal or link CoreRenderMetal only in SuiteImaging (Tests/metal-boundary-baseline.txt)")
        #expect(result.stale == [], "delete these lines from Tests/metal-boundary-baseline.txt: it only shrinks")
    }

    /// SuiteImaging names CoreRenderMetal only inside `#if os(macOS)`, so the
    /// Linux manifest has no Metal backend and SuiteImaging builds without it.
    @Test func theMetalBackendIsMacOSOnly() throws {
        let lines = try Self.read("Package.swift").split(separator: "\n").map(ImagingBoundary.code)
        let declared = try #require(lines.firstIndex { $0.contains("let imagingMetal") && $0.contains("\"CoreRenderMetal\"") })
        let opened = try #require(lines[..<declared].lastIndex { $0.hasPrefix("#if") })
        #expect(lines[opened].trimmingCharacters(in: .whitespaces) == "#if os(macOS)")
        #expect(!lines[opened..<declared].contains { $0.hasPrefix("#else") || $0.hasPrefix("#endif") })
        let target = try #require(lines.firstIndex { $0.contains(".target(name: \"SuiteImaging\"") })
        #expect(lines[target..<min(target + 2, lines.count)].contains { $0.contains("+ imagingMetal)") })
        #if os(Linux) && canImport(CoreRenderMetal)
        Issue.record("CoreRenderMetal is importable on Linux; SuiteImaging must build without it")
        #endif
    }
}
