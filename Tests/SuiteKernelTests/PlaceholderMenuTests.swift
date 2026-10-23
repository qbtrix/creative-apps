// PlaceholderMenuTests.swift (no-placeholders NP-1): no dead menu items. Scans every `Sources/*App/` file as
// text for a menu `Button(` (in a `Commands` type, `CommandMenu`, `CommandGroup` or `.commands { }`) whose
// action is empty, whose modifiers hold a constant `.disabled(true)`, or whose reason is `notConnected(`. A live
// reason (`.disabled(!model.canCut)`) passes, and so does a `Commands` type no line of its app builds (the
// launcher's updater and assets stubs, out of the beta). Each hit must be in Tests/placeholder-menu-baseline.txt
// as `<file>: <trimmed line>` (`#` lines are comments), and a listed line naming no hit fails: the baseline only
// shrinks. Fixtures/Placeholder/Menus.swift.txt (not compiled) holds each kind and the items that pass.
import Foundation
import Testing

/// A placeholder menu item: its file, line, trimmed text, why it is one, and the `Commands` type declaring it.
struct PlaceholderSite: Hashable, Sendable, CustomStringConvertible {
    let file: String, line: Int, text: String
    let kinds: Set<PlaceholderMenuScan.Kind>
    var owner: String?
    var description: String { "\(file):\(line): \(text)" }
}

enum PlaceholderMenuScan {
    enum Kind: String, Hashable, Sendable, CaseIterable {
        case emptyAction = "an empty action", constantDisabled = "a constant .disabled(true)", notConnected = "a notConnected( reason"
    }

    /// The tokens after which the next `{` opens a menu body.
    static let menuStarts = [": Commands", "CommandMenu(", "CommandGroup(", ".commands {"]

    static func key(file: String, text: String) -> String { file + ": " + text }

    /// Every placeholder in each `Sources/*App` folder under `root` (subfolders included), by path then line.
    static func sites(root: URL) throws -> [PlaceholderSite] {
        let sources = root.appendingPathComponent("Sources")
        var found: [PlaceholderSite] = []
        for folder in try FileManager.default.contentsOfDirectory(atPath: sources.path).filter({ $0.hasSuffix("App") }).sorted() {
            let base = sources.appendingPathComponent(folder)
            let files = (FileManager.default.enumerator(atPath: base.path)?.allObjects as? [String] ?? [])
                .filter { $0.hasSuffix(".swift") }.sorted()
            let texts = try files.map { try String(contentsOf: base.appendingPathComponent($0), encoding: .utf8) }
            found += used(zip(files, texts).flatMap { sites(in: $1, file: "Sources/\(folder)/\($0)") }, by: texts)
        }
        return found
    }

    /// The sites whose `Commands` type some non-comment line of `sources` builds, as `Type(`.
    static func used(_ sites: [PlaceholderSite], by sources: [String]) -> [PlaceholderSite] {
        let code = sources.flatMap { $0.split(separator: "\n") }
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.map { Array($0) }
        return sites.filter { site in
            guard let owner = site.owner else { return true }
            return code.contains { line in line.indices.contains { matches(line, at: $0, owner + "(") && startsWord(line, at: $0) } }
        }
    }

    /// The placeholder menu items in one file's text. Comments and strings are skipped.
    static func sites(in text: String, file: String) -> [PlaceholderSite] {
        let chars = Array(text), lines = text.split(separator: "\n", omittingEmptySubsequences: false)
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
                (row, index) = (row + chars[index..<end].filter { $0 == "\n" }.count, end)
                continue
            }
            if char == "{" {
                braces.append((pending || braces.last?.menu == true, owner ?? braces.last?.owner))
                (pending, owner) = (false, nil)
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
        var end = close + 1, emptyTrailing = false
        while end < chars.count, chars[end] == " " { end += 1 }
        if end < chars.count, chars[end] == "{", let body = matchingClose(chars, from: end + 1) {
            (emptyTrailing, end) = (chars[(end + 1)..<body].allSatisfy(\.isWhitespace), body + 1)
        }
        let emptyArgument = arguments.filter { !$0.isWhitespace }.contains("action:{}")
        let modifiers = modifierChain(chars, from: end)
        var kinds: Set<Kind> = []
        if emptyTrailing || emptyArgument { kinds.insert(.emptyAction) }
        if modifiers.contains(".disabled(true)") { kinds.insert(.constantDisabled) }
        if (arguments + modifiers).contains("notConnected(") { kinds.insert(.notConnected) }
        return kinds
    }

    /// The `.modifier(...) { ... }` calls chained from `start` on, across lines.
    static func modifierChain(_ chars: [Character], from start: Int) -> String {
        var index = start, end = start
        while true {
            while index < chars.count, chars[index].isWhitespace { index += 1 }
            guard index + 1 < chars.count, chars[index] == ".", chars[index + 1].isLetter else { break }
            index += 1
            while index < chars.count, chars[index].isLetter || chars[index].isNumber || chars[index] == "_" { index += 1 }
            for open: Character in ["(", "{"] {
                while index < chars.count, chars[index] == " " { index += 1 }
                if index < chars.count, chars[index] == open, let close = matchingClose(chars, from: index + 1) { index = close + 1 }
            }
            end = index
        }
        return String(chars[start..<end])
    }

    /// Whether `token` starts at `index`; a token ending in a letter must end a word there.
    static func matches(_ chars: [Character], at index: Int, _ token: String) -> Bool {
        let token = Array(token), after = index + token.count
        guard after <= chars.count, Array(chars[index..<after]) == token else { return false }
        return !(token.last?.isLetter ?? false) || after >= chars.count || !(chars[after].isLetter || chars[after].isNumber)
    }

    /// `Button(`, not `KeyframeButton(`.
    static func startsWord(_ chars: [Character], at index: Int) -> Bool {
        index == 0 || !(chars[index - 1].isLetter || chars[index - 1].isNumber || chars[index - 1] == "_")
    }

    /// The identifier just before `index`: the type in `struct Name: Commands`.
    static func typeName(_ chars: [Character], before index: Int) -> String? {
        var end = index, start: Int
        while end > 0, chars[end - 1] == " " { end -= 1 }
        start = end
        while !startsWord(chars, at: start) { start -= 1 }
        return start < end ? String(chars[start..<end]) : nil
    }

    /// The index just past the string literal opening at `start`, interpolations and `"""` included.
    static func stringEnd(_ chars: [Character], from start: Int) -> Int {
        let triple = start + 2 < chars.count && chars[start + 1] == "\"" && chars[start + 2] == "\""
        var index = start + (triple ? 3 : 1)
        while index < chars.count {
            let char = chars[index]
            if char == "\\", index + 1 < chars.count {
                if chars[index + 1] == "(", let close = matchingClose(chars, from: index + 2) { index = close + 1 } else { index += 2 }
                continue
            }
            if char == "\"", !triple { return index + 1 }
            if char == "\n", !triple { return index }
            if char == "\"", index + 2 < chars.count, chars[index + 1] == "\"", chars[index + 2] == "\"" { return index + 3 }
            index += 1
        }
        return chars.count
    }

    /// The index of the bracket closing the one open just before `start`, skipping strings.
    static func matchingClose(_ chars: [Character], from start: Int) -> Int? {
        var depth = 1, index = start
        while index < chars.count {
            if chars[index] == "\"" { index = stringEnd(chars, from: index); continue }
            depth += "([{".contains(chars[index]) ? 1 : ")]}".contains(chars[index]) ? -1 : 0
            if depth == 0 { return index }
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
            listed[key(file: String(line[..<gap.lowerBound]), text: String(line[gap.upperBound...])), default: []].append((row + 1, line))
        }
        var problems: [String] = []
        for site in sites {
            let siteKey = key(file: site.file, text: site.text)
            let allowed = listed[siteKey]?.isEmpty == false
            if allowed { listed[siteKey]?.removeFirst(); continue }
            let why = Kind.allCases.filter(site.kinds.contains).map(\.rawValue).joined(separator: ", ")
            problems.append("\(site): a placeholder menu item (\(why)) that \(baselineName) doesn't list;"
                + " make it act, hide it, or disable it with a live reason")
        }
        let stale = listed.values.flatMap { $0 }.sorted { $0.row < $1.row }
        return problems + stale.map { "\(baselineName):\($0.row): `\($0.text)` names no placeholder; delete it (the baseline only shrinks)" }
    }
}

@Suite struct PlaceholderMenuTests {
    static let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    static let root = here.deletingLastPathComponent().deletingLastPathComponent()
    static let fixture = here.appendingPathComponent("Fixtures/Placeholder/Menus.swift.txt")
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
        let raw = PlaceholderMenuScan.sites(in: try String(contentsOf: Self.fixture, encoding: .utf8), file: "f")
        #expect(raw.contains { $0.owner == "UnusedCommands" }, "the scan never saw the unused type's item")
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
        let problems = PlaceholderMenuScan.problems(try PlaceholderMenuScan.sites(root: Self.root), baseline: baseline,
                                                    baselineName: Self.baselineName)
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }
}
