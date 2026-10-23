// PlaceholderMenuTests.swift: no dead menu items (no-placeholders NP-1, MJ-NP).
// A tester's first click should never land on an item that can't act. This
// scans every app's and the launcher's sources (`Sources/*App/`, subfolders
// included) as text for a menu `Button(`, one inside a `Commands` type, a
// `CommandMenu`, a `CommandGroup` or a scene's `.commands { }`, that is a
// placeholder: its action is empty (`{}` or `action: {}`), its modifiers hold
// a constant `.disabled(true)`, or its reason is `notConnected(`. A disabled
// item with a live reason (`.disabled(!model.canCut)`) is no placeholder,
// and neither is one in a `Commands` type no line of its app builds (the
// launcher keeps its updater and assets stubs for those features, out of the
// beta's scenes). Each hit must be listed in
// `Tests/placeholder-menu-baseline.txt` by file and trimmed line
// (`<file>: <line>`; `#` lines are comments), and a listed line that names
// no hit fails too, so the baseline only shrinks. The fixture
// (Fixtures/Placeholder/Menus.swift.txt, .txt so it isn't compiled) holds
// each kind and the items that pass. Files are read by path from #filePath,
// as CommandPathTests does.
import Foundation
import Testing

/// A placeholder menu item: its file, its line, that line's trimmed text and why it is one.
struct PlaceholderSite: Hashable, Sendable, CustomStringConvertible {
    let file: String
    let line: Int
    let text: String
    let kinds: Set<PlaceholderMenuScan.Kind>
    /// The `Commands` type that declares it, nil for a scene's own `.commands { }`.
    var owner: String?
    var description: String { "\(file):\(line): \(text)" }
}

enum PlaceholderMenuScan {
    enum Kind: String, Hashable, Sendable, CaseIterable {
        case emptyAction = "an empty action"
        case constantDisabled = "a constant .disabled(true)"
        case notConnected = "a notConnected( reason"
    }

    /// The tokens after which the next `{` opens a menu body.
    static let menuStarts = [": Commands", "CommandMenu(", "CommandGroup(", ".commands {"]

    static func key(file: String, text: String) -> String { file + ": " + text }

    /// Every placeholder in the `.swift` files of each `Sources/*App` folder under `root`, by path then line.
    static func sites(root: URL) throws -> [PlaceholderSite] {
        let sources = root.appendingPathComponent("Sources")
        let folders = try FileManager.default.contentsOfDirectory(atPath: sources.path).filter { $0.hasSuffix("App") }
        var found: [PlaceholderSite] = []
        for folder in folders.sorted() {
            let base = sources.appendingPathComponent(folder)
            guard let walker = FileManager.default.enumerator(atPath: base.path) else { continue }
            var files: [String] = []
            while let path = walker.nextObject() as? String {
                if path.hasSuffix(".swift") { files.append(path) }
            }
            var texts: [String] = [], folderSites: [PlaceholderSite] = []
            for path in files.sorted() {
                let text = try String(contentsOf: base.appendingPathComponent(path), encoding: .utf8)
                texts.append(text)
                folderSites += sites(in: text, file: "Sources/\(folder)/\(path)")
            }
            found += used(folderSites, by: texts)
        }
        return found
    }

    /// The sites whose `Commands` type some line of `sources` (comment lines aside) builds, as `Type(`.
    static func used(_ sites: [PlaceholderSite], by sources: [String]) -> [PlaceholderSite] {
        let code = sources.flatMap { $0.split(separator: "\n") }
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.map { Array($0) }
        return sites.filter { site in
            guard let owner = site.owner else { return true }
            return code.contains { line in
                line.indices.contains { matches(line, at: $0, owner + "(") && startsWord(line, at: $0) }
            }
        }
    }

    /// The placeholder menu items in one file's text. Comments and strings are skipped.
    static func sites(in text: String, file: String) -> [PlaceholderSite] {
        let chars = Array(text)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var braces: [(menu: Bool, owner: String?)] = []  // per open brace: inside a menu body, and whose
        var pending = false, owner: String?, row = 0, index = 0
        var found: [PlaceholderSite] = []
        while index < chars.count {
            let char = chars[index]
            if char == "\n" { row += 1 }
            if char == "/", index + 1 < chars.count, chars[index + 1] == "/" {
                while index < chars.count, chars[index] != "\n" { index += 1 }
                continue
            }
            if char == "\"" {
                let end = stringEnd(chars, from: index)
                row += chars[index..<end].filter { $0 == "\n" }.count
                index = end
                continue
            }
            if char == "{" {
                braces.append((pending || braces.last?.menu == true, owner ?? braces.last?.owner))
                pending = false
                owner = nil
            } else if char == "}" {
                _ = braces.popLast()
            } else if menuStarts.contains(where: { matches(chars, at: index, $0) }) {
                pending = true
                if char == ":" { owner = typeName(chars, before: index) }
            } else if braces.last?.menu == true, matches(chars, at: index, "Button("), startsWord(chars, at: index) {
                let kinds = classify(chars, from: index + 7)
                if !kinds.isEmpty, row < lines.count {
                    found.append(PlaceholderSite(file: file, line: row + 1, text: lines[row].trimmingCharacters(in: .whitespaces),
                                                 kinds: kinds, owner: braces.last?.owner))
                }
            }
            index += 1
        }
        return found
    }

    /// Why the call whose arguments start at `start` is a placeholder: none when it acts with a live state.
    static func classify(_ chars: [Character], from start: Int) -> Set<Kind> {
        guard let close = matchingClose(chars, from: start) else { return [] }
        let arguments = String(chars[start..<close])
        var end = close + 1
        while end < chars.count, chars[end] == " " { end += 1 }
        var emptyTrailing = false
        if end < chars.count, chars[end] == "{", let body = matchingClose(chars, from: end + 1) {
            emptyTrailing = chars[(end + 1)..<body].allSatisfy(\.isWhitespace)
            end = body + 1
        }
        let emptyArgument = arguments.filter { !$0.isWhitespace }.contains("action:{}")
        let modifiers = modifierChain(chars, from: end)
        var kinds: Set<Kind> = []
        if emptyTrailing || emptyArgument { kinds.insert(.emptyAction) }
        if modifiers.contains(".disabled(true)") { kinds.insert(.constantDisabled) }
        if (arguments + modifiers).contains("notConnected(") { kinds.insert(.notConnected) }
        return kinds
    }

    /// The `.modifier(...)` calls chained from `start` on, across lines.
    static func modifierChain(_ chars: [Character], from start: Int) -> String {
        var index = start, end = start
        while true {
            while index < chars.count, chars[index].isWhitespace { index += 1 }
            guard index + 1 < chars.count, chars[index] == ".", chars[index + 1].isLetter else { break }
            index += 1
            while index < chars.count, chars[index].isLetter || chars[index].isNumber || chars[index] == "_" { index += 1 }
            for open: Character in ["(", "{"] {
                while index < chars.count, chars[index] == " " { index += 1 }
                guard index < chars.count, chars[index] == open, let close = matchingClose(chars, from: index + 1) else { continue }
                index = close + 1
            }
            end = index
        }
        return String(chars[start..<end])
    }

    /// Whether `token` starts at `index`, and a token ending in a letter ends a word there.
    static func matches(_ chars: [Character], at index: Int, _ token: String) -> Bool {
        let token = Array(token)
        guard index + token.count <= chars.count, Array(chars[index..<(index + token.count)]) == token else { return false }
        let after = index + token.count
        return !(token.last?.isLetter ?? false) || after >= chars.count || !(chars[after].isLetter || chars[after].isNumber)
    }

    /// `Button(`, not `KeyframeButton(` or `addButton(`.
    static func startsWord(_ chars: [Character], at index: Int) -> Bool {
        guard index > 0 else { return true }
        let before = chars[index - 1]
        return !(before.isLetter || before.isNumber || before == "_")
    }

    /// The identifier just before `index`: the type in `struct Name: Commands`.
    static func typeName(_ chars: [Character], before index: Int) -> String? {
        var end = index
        while end > 0, chars[end - 1] == " " { end -= 1 }
        var start = end
        while start > 0, chars[start - 1].isLetter || chars[start - 1].isNumber || chars[start - 1] == "_" { start -= 1 }
        return start < end ? String(chars[start..<end]) : nil
    }

    /// The index just past the string literal that opens at `start`, interpolations and `"""` included.
    static func stringEnd(_ chars: [Character], from start: Int) -> Int {
        let triple = start + 2 < chars.count && chars[start + 1] == "\"" && chars[start + 2] == "\""
        var index = start + (triple ? 3 : 1)
        while index < chars.count {
            let char = chars[index]
            if char == "\\", index + 1 < chars.count {
                if chars[index + 1] == "(", let close = matchingClose(chars, from: index + 2) {
                    index = close + 1
                } else {
                    index += 2
                }
                continue
            }
            if char == "\"" {
                if !triple { return index + 1 }
                if index + 2 < chars.count, chars[index + 1] == "\"", chars[index + 2] == "\"" { return index + 3 }
            }
            if char == "\n", !triple { return index }
            index += 1
        }
        return chars.count
    }

    /// The index of the bracket that closes the one open just before `start`, skipping strings.
    static func matchingClose(_ chars: [Character], from start: Int) -> Int? {
        var depth = 1, index = start
        while index < chars.count {
            let char = chars[index]
            if char == "\"" { index = stringEnd(chars, from: index); continue }
            if "([{".contains(char) { depth += 1 }
            if ")]}".contains(char) {
                depth -= 1
                if depth == 0 { return index }
            }
            index += 1
        }
        return nil
    }

    /// The hits `baseline` doesn't list, then the baseline lines that name no hit (the ratchet).
    static func problems(_ sites: [PlaceholderSite], baseline: String, baselineName: String) -> [String] {
        var listed: [String: [(row: Int, text: String)]] = [:]
        for (row, raw) in baseline.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("#"), let gap = line.range(of: ": ") else { continue }
            listed[key(file: String(line[..<gap.lowerBound]), text: String(line[gap.upperBound...])), default: []]
                .append((row + 1, line))
        }
        var problems: [String] = []
        for site in sites {
            let siteKey = key(file: site.file, text: site.text)
            let allowed = listed[siteKey]?.isEmpty == false
            if allowed {
                listed[siteKey]?.removeFirst()
            } else {
                let why = Kind.allCases.filter(site.kinds.contains).map(\.rawValue).joined(separator: ", ")
                problems.append("\(site): a placeholder menu item (\(why)) that \(baselineName) doesn't list;"
                    + " make it act, hide it, or disable it with a live reason")
            }
        }
        let stale = listed.values.flatMap { $0 }.sorted { $0.row < $1.row }
        problems += stale.map { "\(baselineName):\($0.row): `\($0.text)` names no placeholder; delete it (the baseline only shrinks)" }
        return problems
    }
}

@Suite struct PlaceholderMenuTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures").appendingPathComponent("Placeholder").appendingPathComponent("Menus.swift.txt")
    static let baselineName = "Tests/placeholder-menu-baseline.txt"

    static func fixtureSites() throws -> [PlaceholderSite] {
        let text = try String(contentsOf: fixture, encoding: .utf8)
        return PlaceholderMenuScan.used(PlaceholderMenuScan.sites(in: text, file: "Menus.swift.txt"), by: [text])
    }

    /// Each kind in the fixture is found on its own line, and nothing else is.
    @Test func eachKindIsFound() throws {
        let sites = try Self.fixtureSites()
        #expect(sites.map(\.description) == [
            #"Menus.swift.txt:9: Button("Empty") {}"#, #"Menus.swift.txt:10: Button("Disabled") { model?.run() }"#,
            #"Menus.swift.txt:12: Button("Not Connected") { model?.run() }.help(SuiteIdentity.notConnected("fixture"))"#,
            #"Menus.swift.txt:19: Button("Empty Argument", action: {})"#,
        ])
        #expect(sites.map(\.kinds) == [[.emptyAction], [.constantDisabled], [.notConnected], [.emptyAction]])
    }

    /// An empty action fails against an empty baseline, naming its file, line and kind.
    @Test func emptyActionFails() throws {
        let problems = PlaceholderMenuScan.problems(try Self.fixtureSites(), baseline: "", baselineName: "b.txt")
        #expect(problems.count == 4)
        #expect(problems.first?.hasPrefix(#"Menus.swift.txt:9: Button("Empty") {}: a placeholder menu item (an empty action)"#) == true)
        #expect(PlaceholderMenuScan.sites(in: "CommandMenu(\"A\") {\n  Button(\"B\") {\n  }\n}", file: "a").count == 1)
    }

    /// A live reason, a view's button, a comment and an unused Commands type are no placeholders.
    @Test func liveReasonPasses() throws {
        let texts = try Self.fixtureSites().map(\.text)
        #expect(!texts.contains { $0.contains("Live") || $0.contains("View Button") || $0.contains("OK") || $0.contains("Unused") })
        #expect(PlaceholderMenuScan.sites(in: "CommandMenu(\"A\") { Button(\"B\") { go() }.disabled(!ready) }", file: "a").isEmpty)
        let unused = PlaceholderMenuScan.sites(in: try String(contentsOf: Self.fixture, encoding: .utf8), file: "f")
        #expect(unused.contains { $0.owner == "UnusedCommands" }, "the scan never saw the unused type's item")
    }

    /// Only the lines the baseline lists pass; one listed line excuses one hit.
    @Test func baselineOnlyListed() throws {
        let sites = try Self.fixtureSites()
        let first = sites.prefix(1).map { PlaceholderMenuScan.key(file: $0.file, text: $0.text) }.joined()
        let problems = PlaceholderMenuScan.problems(sites, baseline: "# comment\n" + first + "\n", baselineName: "b.txt")
        #expect(problems.count == 3 && !problems.contains { $0.hasPrefix("Menus.swift.txt:9:") }, "\(problems)")
    }

    /// A baseline line that names no hit fails, so the baseline only shrinks.
    @Test func staleBaselineFails() throws {
        let gone = #"Menus.swift.txt: Button("Gone") {}"#
        let problems = PlaceholderMenuScan.problems([], baseline: "# a\n" + gone + "\n", baselineName: "b.txt")
        #expect(problems == ["b.txt:2: `\(gone)` names no placeholder; delete it (the baseline only shrinks)"])
    }

    /// Today's apps and launcher hold exactly the baseline's placeholders.
    @Test func treeMatchesTheBaseline() throws {
        let baseline = try String(contentsOf: Self.root.appendingPathComponent(Self.baselineName), encoding: .utf8)
        let sites = try PlaceholderMenuScan.sites(root: Self.root)
        let problems = PlaceholderMenuScan.problems(sites, baseline: baseline, baselineName: Self.baselineName)
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }
}
