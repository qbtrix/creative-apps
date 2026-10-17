// BuildGraphTests.swift: the two build descriptions must not drift (BU-3,
// route R1 of docs/blueprints/suite.md 2.5). Package.swift is the Linux and
// test graph; project.yml holds the Release graph the bundle is built from.
// Every non-test target the macOS manifest declares must be a target of
// project.yml too. Both files are read by path from #filePath and scanned by
// line, so no YAML library is needed: project.yml's target names sit at a
// two-space indent under its top-level `targets:` key.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing

enum BuildGraph {
    /// The non-test targets of Package.swift on macOS, as the literal forms
    /// write them: `.target(name: "X")`, `.executableTarget(name: "X")`,
    /// `model("X", ...)` (XModel) and `apps.map { .executableTarget(name:
    /// "\($0)App" ... }` over the `apps` array literal (XApp).
    static func packageTargets(_ text: String) -> Set<String> {
        var names = Set<String>()
        for form in [#"\.target\(name: "([A-Za-z]+)""#, #"\.executableTarget\(name: "([A-Za-z]+)""#,
                     #"model\("([A-Za-z]+)""#] {
            for name in captures(form, in: text) { names.insert(form.hasPrefix("model") ? name + "Model" : name) }
        }
        let suffixes = captures(#"apps\.map \{\s*\.executableTarget\(name: "\\\(\$0\)([A-Za-z]+)""#, in: text)
        let apps = captures(#"let apps = \[([^\]]*)\]"#, in: text).first.map { captures(#""([A-Za-z]+)""#, in: $0) } ?? []
        for suffix in suffixes { names.formUnion(apps.map { $0 + suffix }) }
        return names
    }

    /// The names at two-space indent under project.yml's `targets:` key.
    static func projectTargets(_ text: String) -> Set<String> {
        var names = Set<String>()
        var inTargets = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if let first = line.first, first != " ", first != "#" { inTargets = line.hasPrefix("targets:") }
            guard inTargets, line.hasPrefix("  "), !line.hasPrefix("   "),
                  let name = captures(#"^  ([A-Za-z]+):"#, in: String(line)).first else { continue }
            names.insert(name)
        }
        return names
    }

    /// One message per drift: a name of `expected` the manifest lacks, a
    /// manifest name not in `expected`, or a manifest name project.yml lacks.
    static func drift(package: String, project: String, expected: Set<String>) -> [String] {
        let pkg = packageTargets(package)
        let yml = projectTargets(project)
        return expected.subtracting(pkg).sorted().map { "\($0) missing from Package.swift" }
            + pkg.subtracting(expected).sorted().map { "\($0) unexpected in Package.swift" }
            + pkg.subtracting(yml).sorted().map { "\($0) missing from project.yml" }
    }

    /// project.yml's text without one target's block (its name line and the
    /// deeper-indented lines after it).
    static func removingTarget(_ name: String, from text: String) -> String {
        var kept: [Substring] = []
        var skipping = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("  \(name):") { skipping = true; continue }
            if skipping, line.hasPrefix("   ") { continue }
            skipping = false
            kept.append(line)
        }
        return kept.joined(separator: "\n")
    }

    /// project.yml's lines for one target's block, its name line included.
    static func block(_ name: String, in text: String) -> [String] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { $0.hasPrefix("  \(name):") }) else { return [] }
        let rest = lines[(start + 1)...].prefix { $0.hasPrefix("   ") }
        return [lines[start]] + rest
    }

    static func captures(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? Regex(pattern) else { return [] }
        return text.matches(of: regex).compactMap { $0.output.count > 1 ? $0.output[1].substring.map(String.init) : nil }
    }
}

@Suite struct BuildGraphTests {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func read(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    static let expected = Set(["SuiteUI", "SuiteModel", "SuiteKernel", "SuiteShell", "AfterGlowApp"])
        .union(["Flare", "Design", "Photo", "Library", "Halo"].flatMap { ["\($0)Model", "\($0)App"] })

    @Test func packageScanFindsTheMacOSTargets() throws {
        #expect(BuildGraph.packageTargets(try Self.read("Package.swift")) == Self.expected)
    }

    @Test func everyPackageTargetIsInTheReleaseGraph() throws {
        let package = try Self.read("Package.swift"), project = try Self.read("project.yml")
        #expect(BuildGraph.drift(package: package, project: project, expected: Self.expected) == [])
        let extra = BuildGraph.projectTargets(project).subtracting(BuildGraph.packageTargets(package))
        #expect(extra.filter { $0 != "CreativeEngines" && !$0.hasSuffix("JourneyTests") } == [])
        #expect(extra.contains("CreativeEngines"))
    }

    @Test func aTargetDroppedFromProjectYmlIsReported() throws {
        let package = try Self.read("Package.swift"), project = try Self.read("project.yml")
        let without = BuildGraph.removingTarget("SuiteShell", from: project)
        #expect(without != project)
        #expect(BuildGraph.drift(package: package, project: without, expected: Self.expected)
            == ["SuiteShell missing from project.yml"])
    }

    @Test func anAppDroppedFromTheAppsLiteralIsReported() throws {
        let package = try Self.read("Package.swift"), project = try Self.read("project.yml")
        let without = package.replacingOccurrences(of: #", "Halo"]"#, with: "]")
        #expect(without != package)
        #expect(BuildGraph.drift(package: without, project: project, expected: Self.expected)
            == ["HaloApp missing from Package.swift"])
    }

    @Test func afterGlowJourneyBundleCompilesTheSuiteValues() throws {
        let block = BuildGraph.block("AfterGlowJourneyTests", in: try Self.read("project.yml"))
        #expect(block.contains { $0.contains("Journey") && $0.contains("templates") })
        #expect(block.contains { $0.contains("Sources/SuiteModel/Values/") })
    }
}
