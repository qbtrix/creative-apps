// LiveStandInTests.swift: the placeholder ratchet (rule 20's sibling for wiring). It lists every place a live
// path leaves a slot on a stand-in (a `Fake…(`, `NotBuilt…(` or `Unconnected…(` value, a "not built / not
// connected yet" reason, or `.fake` services) and fails on one Tests/live-standins-baseline.txt doesn't list.
// Live paths, scanned as text with `//` lines skipped:
//   - `Sources/*/*Services*.swift`: the bodies of `static let/var/func live` and `built`, and every slot default
//     (`label: … = Fake…()`, `= Unconnected…()`, `= NotBuilt…()`, `(any X)? = nil`) that no builder of that
//     services type passes as `label:`. A `.live` line `label: NotBuilt(…)` that a `built` builder reassigns
//     (`services.label = Live…()`) is overridden and passes.
//   - every file under `Sources/*/Live/` except the stand-in definitions (`NotBuilt*.swift`, `Fake*.swift`).
//   - launch paths: `*Launch.swift`, `*Launch+*.swift`, `*Headless*.swift`, `Sources/*App/*App.swift`,
//     `*Router+Services.swift`, `Sources/*App/*Window+File.swift`.
// Each baseline line is `<file>: <trimmed line>  ## <what retires it>` (an issue, a task id, or `kept: <why>`);
// a line with no retire tag fails, one listed line excuses one hit, and a line naming no hit fails, so the
// baseline only shrinks. A fixture test on a temporary tree proves a new NotBuilt slot on a live builder fails.
import Foundation
import Testing

struct StandInHit: Hashable, Sendable, CustomStringConvertible {
    let file: String, line: Int, text: String
    var description: String { "\(file):\(line): \(text)" }
}

enum StandInScan {
    static func rx(_ pattern: String) -> NSRegularExpression { try! NSRegularExpression(pattern: pattern) }
    /// A stand-in on a live line.
    static let standIn = rx(#"\b(?:NotBuilt|Unconnected)\w*\(|\bFake[A-Z]\w*\(|=\s*\w*Services\.fake\b|services:\s*\.fake\b|(?i:\b(?:not|isn't|isn’t) (?:built|connected) yet)"#)
    /// A slot default left on a stand-in: group 1 is the slot's label.
    static let slotDefault = rx(#"(\w+)\s*:\s*(?:any\s+[\w.]+\s*=\s*(?:NotBuilt|Unconnected|Fake[A-Z])\w*\(|\(any\s+[\w.]+\)\?\s*=\s*nil\b)"#)
    /// The header of a live builder.
    static let builder = rx(#"\bstatic\s+(?:let|var|func)\s+(?:live|built)\b"#)
    /// `services.label = Live…(`: a builder reassigning a slot to something that isn't a stand-in.
    static let override = rx(#"\.(\w+)\s*=\s*(?!(?:NotBuilt|Unconnected|Fake[A-Z])\w*\()\w"#)
    /// A `.live` line that sets one slot: `label: …`.
    static let labelled = rx(#"^(\w+)\s*:"#)

    static func matches(_ rx: NSRegularExpression, _ text: String) -> [[String]] {
        rx.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { m in
            (0..<m.numberOfRanges).map { Range(m.range(at: $0), in: text).map { String(text[$0]) } ?? "" }
        }
    }

    static func isLaunchPath(_ path: String) -> Bool {
        let name = path.split(separator: "/").last.map(String.init) ?? path, folder = path.split(separator: "/").dropLast().last ?? ""
        return name.hasSuffix("Launch.swift") || name.contains("Launch+") || name.contains("Headless")
            || name.hasSuffix("Router+Services.swift")
            || (folder.hasSuffix("App") && (name == folder + ".swift" || name.hasSuffix("Window+File.swift")))
    }

    static func isLiveFile(_ path: String) -> Bool {
        let name = path.split(separator: "/").last ?? ""
        return path.contains("/Live/") && !name.hasPrefix("NotBuilt") && !name.hasPrefix("Fake")
    }

    /// `Sources/SuiteShell/SuiteServices+Live.swift` -> `SuiteServices`; nil for a file that isn't a services file
    /// (`LauncherRouter+Services.swift` is a launch path, not a services type).
    static func servicesType(_ path: String) -> String? {
        let parts = path.split(separator: "/")
        guard parts.count == 3, parts[0] == "Sources", let r = parts[2].range(of: "Services") else { return nil }
        let type = String(parts[2][..<r.upperBound])
        return type.contains("+") ? nil : type
    }

    /// Code lines (1-based row, text), `//` lines dropped.
    static func code(_ text: String) -> [(row: Int, text: String)] {
        text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            .map { ($0.offset + 1, String($0.element)) }
            .filter { !$0.1.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }

    /// The rows inside live builders: from each header to the line where its brackets close.
    static func builderRows(_ lines: [(row: Int, text: String)]) -> Set<Int> {
        var rows: Set<Int> = [], depth = 0, inside = false, opened = false
        for (row, text) in lines {
            if !inside, !matches(builder, text).isEmpty { (inside, opened, depth) = (true, false, 0) }
            guard inside else { continue }
            rows.insert(row)
            var quoted = false
            for char in text {
                if char == "\"" { quoted.toggle() }
                if quoted { continue }
                if "([{".contains(char) { depth += 1; opened = true }
                if ")]}".contains(char) { depth -= 1 }
            }
            if opened, depth <= 0 { inside = false }
        }
        return rows
    }

    /// Every stand-in on a live path under `root`, by path then line.
    static func hits(root: URL) throws -> [StandInHit] {
        let sources = root.appendingPathComponent("Sources")
        let all = (FileManager.default.enumerator(atPath: sources.path)?.allObjects as? [String] ?? [])
            .filter { $0.hasSuffix(".swift") }.map { "Sources/" + $0 }.sorted()
        var texts: [String: [(row: Int, text: String)]] = [:]
        for path in all where servicesType(path) != nil || isLiveFile(path) || isLaunchPath(path) {
            texts[path] = code(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
        }
        // Per services type: the builder lines of all its files, the labels they pass, and the slots they reassign.
        var built: [String: [String]] = [:]
        for (path, lines) in texts {
            guard let type = servicesType(path) else { continue }
            let rows = builderRows(lines)
            built[type, default: []] += lines.filter { rows.contains($0.row) }.map(\.text)
        }
        var found: [StandInHit] = []
        for path in all {
            guard let lines = texts[path] else { continue }
            let type = servicesType(path)
            let rows = type == nil ? Set(lines.map(\.row)) : builderRows(lines)
            let body = type.map { built[$0] ?? [] } ?? []
            let overridden = Set(body.flatMap { matches(override, $0).map { $0[1] } })
            for (row, text) in lines {
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                var hit = rows.contains(row) && !matches(standIn, text).isEmpty
                if hit, type != nil, let label = matches(labelled, trimmed).first?[1], overridden.contains(label) { hit = false }
                if !hit, type != nil, !rows.contains(row) {
                    hit = matches(slotDefault, text).contains { m in !body.contains { $0.contains(m[1] + ":") } }
                }
                if hit { found.append(StandInHit(file: path, line: row, text: trimmed)) }
            }
        }
        return found
    }

    /// The hits `baseline` doesn't list, the lines with no retire tag, then the lines that name no hit.
    static func problems(_ hits: [StandInHit], baseline: String, name: String) -> [String] {
        var listed: [String: [(row: Int, text: String)]] = [:], problems: [String] = []
        for (row, raw) in baseline.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.components(separatedBy: "  ## ")
            if parts.count < 2 || parts.last!.trimmingCharacters(in: .whitespaces).isEmpty {
                problems.append("\(name):\(row + 1): `\(line)` names nothing that retires it; end it with `  ## <issue or task>`")
            }
            listed[parts[0], default: []].append((row + 1, line))
        }
        for hit in hits {
            let key = hit.file + ": " + hit.text
            if listed[key]?.isEmpty == false { listed[key]?.removeFirst(); continue }
            problems.append("\(hit): a stand-in on a live path that \(name) doesn't list; wire the live type, or list it"
                + " with the feature or issue that retires it")
        }
        let stale = listed.values.flatMap { $0 }.sorted { $0.row < $1.row }
        return problems + stale.map { "\(name):\($0.row): `\($0.text)` names no stand-in; delete it (the baseline only shrinks)" }
    }
}

@Suite struct LiveStandInTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let name = "Tests/live-standins-baseline.txt"

    static func withTree<T>(_ files: [String: String], _ body: (URL) throws -> T) throws -> T {
        let tree = FileManager.default.temporaryDirectory.appendingPathComponent("standin-ratchet-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tree) }
        for (path, text) in files {
            let url = tree.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return try body(tree)
    }

    static let services = """
        public struct FooServices {
            public var a: any A
            public var text: any TextServices = FakeText()
            public var note: (any Note)? = nil
            public init(a: any A, b: any B = UnconnectedB(), c: any C = FakeC()) {}
            public static var fake: FooServices { FooServices(a: FakeA(), b: FakeB(), c: FakeC()) }
            public static var live: FooServices {
                FooServices(
                    a: LiveA(),
                    b: NotBuilt(reason: "Not connected yet (X-1)."),
                    c: LiveC())
            }
        }
        """

    static func fixtureHits(_ extra: [String: String] = [:]) throws -> [StandInHit] {
        try withTree(["Sources/FooModel/FooServices.swift": services].merging(extra) { $1 }) { try StandInScan.hits(root: $0) }
    }

    /// The fixture's live builder, its unpassed defaults and its live files are found; the fake builder, a passed
    /// default and the stand-in definitions aren't.
    @Test func fixtureFindsEachKind() throws {
        let hits = try Self.fixtureHits([
            "Sources/FooModel/Live/LiveB.swift": "// NotBuilt(\nlet help = \"Trash isn't connected yet.\"\n",
            "Sources/FooModel/Live/NotBuilt.swift": "struct NotBuilt { let r = \"Not built yet\" }\n",
            "Sources/FooApp/FooApp.swift": "static let host = Catalog(services: .fake())\nlet s = x ? FooServices.live : FooServices.fake\n",
        ])
        #expect(hits.map(\.description) == [
            "Sources/FooApp/FooApp.swift:1: static let host = Catalog(services: .fake())",
            "Sources/FooModel/FooServices.swift:3: public var text: any TextServices = FakeText()",
            "Sources/FooModel/FooServices.swift:4: public var note: (any Note)? = nil",
            #"Sources/FooModel/FooServices.swift:10: b: NotBuilt(reason: "Not connected yet (X-1)."),"#,
            #"Sources/FooModel/Live/LiveB.swift:2: let help = "Trash isn't connected yet.""#,
        ], "\(hits)")
    }

    /// Adding a new NotBuilt slot to a live builder fails against a baseline that lists today's stand-ins.
    @Test func newNotBuiltSlotOnALiveBuilderFails() throws {
        let today = try Self.fixtureHits().map { "\($0.file): \($0.text)  ## X-1" }.joined(separator: "\n")
        #expect(StandInScan.problems(try Self.fixtureHits(), baseline: today, name: "b.txt").isEmpty)
        let grown = Self.services.replacingOccurrences(of: "c: LiveC())", with: "c: NotBuilt(reason: \"later\"))")
        let hits = try Self.fixtureHits(["Sources/FooModel/FooServices.swift": grown])
        #expect(StandInScan.problems(hits, baseline: today, name: "b.txt") == [
            #"Sources/FooModel/FooServices.swift:11: c: NotBuilt(reason: "later")): a stand-in on a live path that b.txt"#
                + " doesn't list; wire the live type, or list it with the feature or issue that retires it",
        ])
    }

    /// A `built` builder that reassigns a `.live` NotBuilt slot clears it; a slot a builder passes isn't a default hit.
    @Test func builtOverrideAndPassedDefaultPass() throws {
        let built = "extension FooServices {\n    static var built: FooServices {\n        var s = FooServices.live\n"
            + "        s.b = LiveB()\n        return s\n    }\n}\n"
        let hits = try Self.fixtureHits(["Sources/FooModel/FooServicesBuilt.swift": built])
        #expect(!hits.contains { $0.text.hasPrefix("b: NotBuilt") }, "\(hits)")
        #expect(!hits.contains { $0.text.contains("UnconnectedB") || $0.text.contains("c: any C") }, "\(hits)")
    }

    /// A line with no retire tag fails, and so does a line naming no stand-in.
    @Test func untaggedAndStaleLinesFail() {
        let problems = StandInScan.problems([StandInHit(file: "a.swift", line: 1, text: "x: FakeX()")],
                                            baseline: "# c\na.swift: x: FakeX()\nb.swift: gone  ## X-2\n", name: "b.txt")
        #expect(problems == [
            "b.txt:2: `a.swift: x: FakeX()` names nothing that retires it; end it with `  ## <issue or task>`",
            "b.txt:3: `b.swift: gone  ## X-2` names no stand-in; delete it (the baseline only shrinks)",
        ])
    }

    /// Today's live paths hold exactly the baseline's stand-ins.
    @Test func treeMatchesTheBaseline() throws {
        let baseline = try String(contentsOf: Self.root.appendingPathComponent(Self.name), encoding: .utf8)
        let problems = StandInScan.problems(try StandInScan.hits(root: Self.root), baseline: baseline, name: Self.name)
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }
}
