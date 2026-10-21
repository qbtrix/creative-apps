// CommandPathTests.swift: the one command path (command-catalog CC-11, slice
// CC-lint, CJ3). Every menu item and toolbar button in an app is built from a
// command spec, `MenuCommand(spec, on: target)` (CC-9), so menus, buttons, the
// CLI and MCP drive the same catalog. This scans each app's sources,
// `Sources/<X>App/` and its subfolders, as text for `MenuCommand(` and
// `Button(` calls without an `on:` argument, and fails on any that
// `Tests/command-path-baseline/<app>.txt` doesn't list. A baseline line is
// `<file>: <the call's trimmed line>`, so it excuses that line only, never a
// new site in the same file. The baselines hold the sites that predate the
// catalog; adopt-command-catalog removes them as each app moves onto specs.
// A baseline line whose site is gone fails too (CC-12), so baselines only
// shrink. A fixture tree (Fixtures/CommandPath/, .txt so it isn't compiled) proves
// both directions. Files are read by path from #filePath.
import Foundation
import Testing

/// A menu item or button call built without a spec: its file (relative to the
/// scanned root), its line, and that line's trimmed text.
struct CommandSite: Hashable, Sendable, CustomStringConvertible {
    let file: String
    let line: Int
    let text: String
    var description: String { "\(file):\(line): \(text)" }
}

enum CommandPathScan {
    static let callees = ["MenuCommand(", "Button("]

    /// What a baseline line and a site are matched on: the file and the line's text.
    static func key(file: String, text: String) -> String { file + ": " + text }

    /// Every site under `root/folder`, subfolders included, in files ending in `suffix`, by path then line.
    static func sites(root: URL, folder: String, suffix: String = ".swift") throws -> [CommandSite] {
        let base = root.appendingPathComponent(folder)
        guard let walker = FileManager.default.enumerator(atPath: base.path) else { return [] }
        var files: [String] = []
        while let path = walker.nextObject() as? String {
            if path.hasSuffix(suffix) { files.append(path) }
        }
        var found: [CommandSite] = []
        for path in files.sorted() {
            let text = try String(contentsOf: base.appendingPathComponent(path), encoding: .utf8)
            found += sites(in: text, file: folder + "/" + path)
        }
        return found
    }

    /// The calls in one file's text that are not built from a spec.
    static func sites(in text: String, file: String) -> [CommandSite] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var found: [CommandSite] = []
        for (row, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") { continue }
            for callee in callees {
                for range in line.ranges(of: callee) where startsCall(line, at: range.lowerBound) {
                    let following = lines.dropFirst(row + 1).prefix(40).joined(separator: "\n")
                    if !builtFromSpec(line[range.upperBound...] + "\n" + following) {
                        found.append(CommandSite(file: file, line: row + 1, text: trimmed))
                    }
                }
            }
        }
        return found
    }

    /// The name is a whole identifier: `Button(`, not `KeyframeButton(` or `addButton(`.
    static func startsCall(_ line: Substring, at index: Substring.Index) -> Bool {
        guard index > line.startIndex else { return true }
        let before = line[line.index(before: index)]
        return !(before.isLetter || before.isNumber || before == "_")
    }

    /// Whether the call's own arguments (from just after its `(` to the matching `)`)
    /// carry an `on:` label, the spec initializer's. Closures after the `)` don't count.
    static func builtFromSpec(_ arguments: String) -> Bool {
        var depth = 1, inString = false, escaped = false, token = ""
        for char in arguments {
            if inString {
                if escaped { escaped = false } else if char == "\\" { escaped = true } else if char == "\"" { inString = false }
                continue
            }
            switch char {
            case "\"": inString = true; token = ""
            case "(", "[", "{": depth += 1; token = ""
            case ")", "]", "}":
                depth -= 1; token = ""
                if depth == 0 { return false }
            case ":":
                if depth == 1 && token == "on" { return true }
                token = ""
            default: token = char.isLetter || char.isNumber || char == "_" ? token + String(char) : ""
            }
        }
        return false
    }

    /// The sites `baseline` doesn't list, each named by file and line, then the baseline lines
    /// that name no site (CC-12, the ratchet), each named by its line in the baseline. Each
    /// baseline line excuses one site, so a baseline only shrinks.
    static func problems(_ sites: [CommandSite], baseline: String, baselineName: String) -> [String] {
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
            if let left = listed[siteKey], !left.isEmpty {
                listed[siteKey] = Array(left.dropFirst())
            } else {
                problems.append("\(site.file):\(site.line): `\(site.text)` builds a menu item or button without a command"
                    + " spec and \(baselineName) doesn't list it; build it with MenuCommand(spec, on:) from the app's catalog")
            }
        }
        let stale = listed.values.flatMap { $0 }.sorted { $0.row < $1.row }
        problems += stale.map { "\(baselineName):\($0.row): `\($0.text)` names no site; remove it from the baseline" }
        return problems
    }
}

@Suite struct CommandPathTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures").appendingPathComponent("CommandPath")
    static let apps = ["photo": "PhotoApp", "design": "DesignApp", "flare": "FlareApp", "halo": "HaloApp", "library": "LibraryApp",
                       "shell": "SuiteShell", "launcher": "AfterGlowApp"]

    static func fixtureSites() throws -> [CommandSite] {
        try CommandPathScan.sites(root: fixture, folder: "Sources/FixtureApp", suffix: ".swift.txt")
    }

    static func fixtureBaseline(_ name: String) throws -> String {
        try String(contentsOf: fixture.appendingPathComponent(name), encoding: .utf8)
    }

    /// CJ3: with no baseline, the bare menu item one folder down and the bare toolbar button fail, by file and line.
    @Test func bareSiteFailsNamingFileAndLine() throws {
        let sites = try Self.fixtureSites()
        #expect(sites == [
            CommandSite(file: "Sources/FixtureApp/Menus/BareMenu.swift.txt", line: 5,
                        text: #"MenuCommand("X", help: "", perform: {})"#),
            CommandSite(file: "Sources/FixtureApp/Toolbar.swift.txt", line: 5,
                        text: #"Button("Zoom In", systemImage: "plus.magnifyingglass") { zoom(on: 2) }"#),
        ])
        let problems = CommandPathScan.problems(sites, baseline: "", baselineName: "fixture.txt")
        #expect(problems.count == 2)
        #expect(problems.first?.hasPrefix(#"Sources/FixtureApp/Menus/BareMenu.swift.txt:5: `MenuCommand("X""#) == true)
        #expect(problems.allSatisfy { $0.contains("fixture.txt doesn't list it") })
    }

    /// CJ3: the same lines listed in the fixture baseline pass.
    @Test func listedSitePasses() throws {
        let problems = CommandPathScan.problems(try Self.fixtureSites(), baseline: try Self.fixtureBaseline("baseline-listed.txt"),
                                                baselineName: "baseline-listed.txt")
        #expect(problems.isEmpty, "\(problems)")
    }

    /// A baseline line names a line, not a file: another line of a listed file still fails.
    @Test func baselineMatchesLineNotFile() throws {
        let problems = CommandPathScan.problems(try Self.fixtureSites(), baseline: try Self.fixtureBaseline("baseline-wrong-line.txt"),
                                                baselineName: "baseline-wrong-line.txt")
        #expect(problems.filter { $0.contains("doesn't list it") }.count == 2)
        #expect(problems.first?.hasPrefix("Sources/FixtureApp/Menus/BareMenu.swift.txt:5:") == true)
    }

    /// CC-12, the ratchet: a baseline line whose site is gone fails, naming the baseline line, so baselines only shrink.
    @Test func staleBaselineFails() throws {
        let listed = try Self.fixtureBaseline("baseline-listed.txt")
        let gone = #"Sources/FixtureApp/Toolbar.swift.txt: Button("Fit") { fit() }"#
        let problems = CommandPathScan.problems(try Self.fixtureSites(), baseline: listed + gone + "\n", baselineName: "b.txt")
        #expect(problems == ["b.txt:4: `\(gone)` names no site; remove it from the baseline"])
        let once = CommandPathScan.problems(try Self.fixtureSites(), baseline: listed + listed, baselineName: "b.txt")
        #expect(once.count == 2 && once.allSatisfy { $0.hasSuffix("remove it from the baseline") }, "\(once)")
    }

    /// Calls built from a spec (one line or several), comments, and longer names are never sites.
    @Test func specBuiltSitePasses() throws {
        #expect(try Self.fixtureSites().allSatisfy { !$0.file.hasSuffix("SpecMenus.swift.txt") })
        #expect(CommandPathScan.sites(in: "MenuCommand(spec, on: doc) {}", file: "a").isEmpty)
        #expect(CommandPathScan.sites(in: "MenuCommand(\n  spec,\n  on: doc\n)", file: "a").isEmpty)
        #expect(CommandPathScan.sites(in: #"MenuCommand("\(on): x", help: "") { go(on: 1) }"#, file: "a").count == 1)
    }

    /// CS-2, the dismiss rule: a Cancel, Close or Done whose action only dismisses its sheet
    /// (an empty closure, a dismiss call, a flag set to false or nil) is not a bare control.
    @Test func dismissOnlyDismisses() {
        let dismissals = [
            #"Button("Cancel", role: .cancel) { onCancel() }"#,
            #"Button("Close", systemImage: "xmark") { onClose?() }"#,
            #"Button("Done") { actions.close?() }.keyboardShortcut(.defaultAction)"#,
            #"Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)"#,
            #"Button("Cancel", role: .cancel) {}"#,
            #"Button("Cancel", role: .cancel) { request = nil }"#,
            "Button(\"Done\") {\n    showing = false\n    dismiss()\n}",
        ]
        for text in dismissals {
            #expect(CommandPathScan.sites(in: text, file: "a").isEmpty, "\(text)")
        }
        let edits = [
            #"Button("Cancel") { dismiss(); model.reset() }"#,
            "Button(\"Done\") {\n    model.apply()\n    dismiss()\n}",
            #"Button("Cancel", action: model.revert)"#,
            #"Button("Cancel") { actions.cancel?() }"#,
            #"Button("Close") { NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil) }"#,
            #"Button("Delete") { dismiss() }"#,
            #"Button("Remove", action: onClose)"#,
            #"Button(title) { dismiss() }"#,
        ]
        for text in edits {
            #expect(CommandPathScan.sites(in: text, file: "a").count == 1, "\(text)")
        }
    }

    /// Today's apps, the suite shell and the launcher pass against the baselines generated from them.
    @Test(arguments: ["photo", "design", "flare", "halo", "library", "shell", "launcher"])
    func appMatchesItsBaseline(app: String) throws {
        let folder = try #require(Self.apps[app])
        let name = "Tests/command-path-baseline/\(app).txt"
        let baseline = try String(contentsOf: Self.root.appendingPathComponent(name), encoding: .utf8)
        let sites = try CommandPathScan.sites(root: Self.root, folder: "Sources/\(folder)")
        #expect(!sites.isEmpty)
        let problems = CommandPathScan.problems(sites, baseline: baseline, baselineName: name)
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }
}
