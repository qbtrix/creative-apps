// FormatListRatchetTests.swift: one image-format list (shared-codecs SC-13,
// rule 20). SuiteModel's `SuiteImageFormats` names every format the suite
// reads and writes; no other `.swift` under `Sources/` may spell out its own
// list. A list is two or more different image formats (png, jpeg, heic, heif,
// tiff, webp, gif, bmp, exr, tga, camera raw) named in one line, one
// innermost `{ }` block (a switch) or one outermost `[ ]` literal, as
// `.png` members, `"jpg"` or `"public.tiff"` strings, or bare `case png,
// jpeg` cases. Comments don't count. Today's offenders are listed in
// `Tests/format-lists-baseline.txt`: a listed file with no list is fine, so
// SC-15 and SC-16 shrink the tree with its lines, and the baseline never
// grows past `baselineCap`. SC-16 deletes it and the ratchet goes strict.
// `ExportFormats.all` keeps its write capabilities (export-pack);
// `ImageFormatParityTests` holds its still ids to the registry's writable
// ones, so its file is allowed. Files are read by path from #filePath.
import Foundation
import Testing

enum FormatListScan {
    /// The files allowed to list formats, and why.
    static let allowed: [String: String] = [
        "Sources/SuiteModel/Values/SuiteImageFormats.swift": "the registry",
        "Sources/SuiteKernel/Export/ExportOptions.swift": "write capabilities; ImageFormatParityTests ties them to the registry",
    ]

    /// A spelling and the format it names; jpg is jpeg, tif is tiff.
    static let words: [String: String] = {
        var map = ["jpg": "jpeg", "tif": "tiff", "openexr": "exr", "heif": "heif"]
        for word in ["png", "jpeg", "heic", "tiff", "webp", "gif", "bmp", "exr", "tga"] { map[word] = word }
        for raw in ["cr2", "cr3", "nef", "nrw", "arw", "sr2", "raf", "orf", "rw2", "dng", "pef", "srw", "3fr", "iiq", "erf", "x3f"] {
            map[raw] = "raw"
        }
        return map
    }()

    /// The format a whole string literal names: "png", "JPEG", "public.tiff", "com.ilm.openexr-image".
    static func format(string: String) -> String? {
        var text = string.lowercased()
        if text.hasSuffix("-image") { text.removeLast(6) }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard let last = parts.last, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } }) else { return nil }
        // "png", or a type id ("public.png", "com.ilm.openexr-image"), never a file name ("dot.png").
        guard parts.count == 1 || parts.first == "public" || parts.count >= 3 else { return nil }
        return words[last]
    }

    struct Token { let format: String; let offset: Int; let line: Int }

    /// The format tokens and the `{ }` / `[ ]` spans in one file's code, comments skipped.
    static func tokens(_ text: String) -> (tokens: [Token], spans: [Range<Int>]) {
        let chars = Array(text)
        var tokens: [Token] = [], spans: [Range<Int>] = []
        var braces: [(start: Int, nested: Bool)] = [], brackets: [Int] = []
        var line = 1, i = 0
        func isIdent(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }
        func word(at start: Int) -> String {
            var end = start
            while end < chars.count, isIdent(chars[end]) { end += 1 }
            return String(chars[start..<end])
        }
        func lineStartsWithCase(_ at: Int) -> Bool {
            var start = at
            while start > 0, !"\n{;".contains(chars[start - 1]) { start -= 1 }
            let head = String(chars[start..<at]).trimmingCharacters(in: .whitespaces)
            return head == "case" || head.hasPrefix("case ")
        }
        while i < chars.count {
            let c = chars[i]
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            if c == "\n" { line += 1; i += 1; continue }
            if c == "/", next == "/" {
                while i < chars.count, chars[i] != "\n" { i += 1 }
                continue
            }
            if c == "/", next == "*" {
                i += 2
                while i + 1 < chars.count, !(chars[i] == "*" && chars[i + 1] == "/") { if chars[i] == "\n" { line += 1 }; i += 1 }
                i += 2
                continue
            }
            if c == "\"" {
                let triple = i + 2 < chars.count && chars[i + 1] == "\"" && chars[i + 2] == "\""
                let start = i, startLine = line
                i += triple ? 3 : 1
                var body = ""
                while i < chars.count {
                    if chars[i] == "\\" { body.append(chars[i]); i += 2; continue }
                    if triple, i + 2 < chars.count, chars[i] == "\"", chars[i + 1] == "\"", chars[i + 2] == "\"" { i += 3; break }
                    if !triple, chars[i] == "\"" { i += 1; break }
                    if !triple, chars[i] == "\n" { break }
                    if chars[i] == "\n" { line += 1 }
                    body.append(chars[i]); i += 1
                }
                if !triple, let format = format(string: body) { tokens.append(Token(format: format, offset: start, line: startLine)) }
                continue
            }
            switch c {
            case "{":
                if let last = braces.indices.last { braces[last].nested = true }
                braces.append((i, false))
            case "}":
                if let open = braces.popLast(), !open.nested { spans.append(open.start..<i + 1) }
            case "[": brackets.append(i)
            case "]":
                if let open = brackets.popLast(), brackets.isEmpty { spans.append(open..<i + 1) }
            case ".":
                let name = word(at: i + 1)
                var before = i
                while before > 0, isIdent(chars[before - 1]) { before -= 1 }
                let owner = String(chars[before..<i])
                if let format = words[name.lowercased()], owner.isEmpty || owner.first?.isUppercase == true {
                    tokens.append(Token(format: format, offset: i, line: line))
                }
                i += 1 + name.count
                continue
            default:
                if isIdent(c), i == 0 || !isIdent(chars[i - 1]) && chars[i - 1] != "." {
                    let name = word(at: i)
                    if let format = words[name], lineStartsWithCase(i) { tokens.append(Token(format: format, offset: i, line: line)) }
                    i += name.count
                    continue
                }
            }
            i += 1
        }
        return (tokens, spans)
    }

    /// Whether one file's text spells out a format list.
    static func hasList(_ text: String) -> Bool {
        let (tokens, spans) = tokens(text)
        let byLine = Dictionary(grouping: tokens, by: \.line).values.map { Set($0.map(\.format)) }
        if byLine.contains(where: { $0.count >= 2 }) { return true }
        return spans.contains { span in Set(tokens.filter { span.contains($0.offset) }.map(\.format)).count >= 2 }
    }

    /// The paths in `files` (path to text) that list formats, but the allowed ones, sorted.
    static func hits(_ files: [String: String]) -> [String] {
        files.filter { allowed[$0.key] == nil && hasList($0.value) }.map(\.key).sorted()
    }

    /// The baseline's paths: one per line, `#` comments and blank lines skipped.
    static func listed(_ baseline: String) -> Set<String> {
        Set(baseline.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") })
    }

    /// One message per hit the baseline doesn't list.
    static func problems(_ files: [String: String], baseline: String) -> [String] {
        let allowed = listed(baseline)
        return hits(files).filter { !allowed.contains($0) }.map {
            "\($0) lists image formats; take them from SuiteImageFormats"
        }
    }

    /// Every `.swift` under `root/Sources`, by path relative to root.
    static func sources(root: URL) throws -> [String: String] {
        let base = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else { return [:] }
        var files: [String: String] = [:]
        while let path = walker.nextObject() as? String {
            guard path.hasSuffix(".swift") else { continue }
            files["Sources/" + path] = try String(contentsOf: base.appendingPathComponent(path), encoding: .utf8)
        }
        return files
    }
}

@Suite struct FormatListRatchetTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static func baseline() throws -> String {
        try String(contentsOf: root.appendingPathComponent("Tests/format-lists-baseline.txt"), encoding: .utf8)
    }
    /// Today's baseline size; a slice lowers it with its lines, nothing raises it.
    static let baselineCap = 25

    /// A temp tree holding `files` (path to text) under its root.
    static func tree(_ files: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("format-lists-\(UUID().uuidString)")
        for (path, text) in files {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return root
    }

    /// A new `[.png, .jpeg]` in DesignApp fails, scanned from a tree on disk, even with today's baseline.
    @Test func newListFails() throws {
        let root = try Self.tree(["Sources/DesignApp/X.swift": "let types: [UTType] = [.png, .jpeg]\n",
                                  "Sources/DesignApp/Clean.swift": "let a = 1\n"])
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(FormatListScan.problems(try FormatListScan.sources(root: root), baseline: try Self.baseline())
            == ["Sources/DesignApp/X.swift lists image formats; take them from SuiteImageFormats"])
    }

    /// Each spelling of a list is one: strings, type ids, bare cases, a switch, a literal over lines.
    @Test(arguments: [
        #"let open = ["png", "jpg"]"#,
        #"let ids = ["public.tiff", "com.compuserve.gif"]"#,
        "enum F { case png, jpeg }",
        "switch f {\ncase .jpeg: .jpeg\ncase .heic: .heic\n}",
        "let all = [\n    .webp,\n    .bmp,\n]",
        "let t = UTType.png; let u = UTType.tiff",
    ])
    func spellingsAreLists(text: String) {
        #expect(FormatListScan.hasList(text), "\(text)")
    }

    /// One format, aliases of one format, comments, prose and lowercase properties are not lists.
    @Test(arguments: [
        "write(to: url, as: .png)",
        #"case "jpg", "jpeg": self = .jpeg"#,
        "// [.png, .jpeg]",
        #"let why = "Photo opens .png and .jpeg files.""#,
        "let a = doc.png; let b = doc.jpeg",
        #"let names = ["dot.png", "Untitled.jpeg"]"#,
        "func f() { let png = 1 }\nfunc g() { let jpeg = 2 }",
    ])
    func othersAreNotLists(text: String) {
        #expect(!FormatListScan.hasList(text), "\(text)")
    }

    /// The registry and ExportFormats.all may list; a listed file with no list never fails.
    @Test func allowedAndListedPass() {
        let files = ["Sources/SuiteModel/Values/SuiteImageFormats.swift": "[.png, .jpeg]",
                     "Sources/SuiteKernel/Export/ExportOptions.swift": #"["png", "jpeg"]"#,
                     "Sources/PhotoModel/Gone.swift": "let a = 1"]
        #expect(FormatListScan.problems(files, baseline: "# c\nSources/PhotoModel/Gone.swift\n").isEmpty)
    }

    /// Today's tree passes against the baseline, and the baseline never grows.
    @Test func realTreePasses() throws {
        let files = try FormatListScan.sources(root: Self.root)
        #expect(!files.isEmpty)
        let problems = FormatListScan.problems(files, baseline: try Self.baseline())
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
        #expect(FormatListScan.listed(try Self.baseline()).count <= Self.baselineCap)
    }
}
