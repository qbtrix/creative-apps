// CommandPathLimitTests.swift: the limit on each command-path baseline
// (command-state CS-2, slice CS-a). Every Tests/command-path-baseline/*.txt
// carries `# max: N` as its second line, and the file may list at most N sites.
// An app slice that moves controls onto commands drops its lines and lowers N
// to match, so a baseline can never grow back: a new bare control fails here
// even when someone adds its line to the baseline.
import Foundation
import Testing

enum CommandPathLimit {
    /// The baseline's `# max: N` header (its second line) against its entries
    /// (the lines that are neither blank nor comments): the header is missing or
    /// malformed, or the entries outnumber N.
    static func problems(baseline: String, name: String) -> [String] {
        let lines = baseline.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let prefix = "# max: "
        guard lines.count > 1, lines[1].hasPrefix(prefix), let max = Int(lines[1].dropFirst(prefix.count)) else {
            return ["\(name): its second line must be `# max: N`"]
        }
        let entries = lines.filter { !$0.isEmpty && !$0.hasPrefix("#") }.count
        if entries > max {
            return ["\(name) holds \(entries) sites over its # max: \(max); move a control onto a command instead"]
        }
        return []
    }
}

@Suite struct CommandPathLimitTests {
    static let baselines = ["design", "flare", "halo", "library", "photo", "shell", "launcher"]

    /// The limit caps the entries: 3 lines under `# max: 2` fail, 2 or fewer pass.
    @Test func limitCaps() {
        let header = "# Fixture's bare sites.\n# max: 2\n"
        let three = header + "A.swift: Button(\"A\") {}\nA.swift: Button(\"B\") {}\nA.swift: Button(\"C\") {}\n"
        #expect(CommandPathLimit.problems(baseline: three, name: "f.txt") == ["f.txt holds 3 sites over its # max: 2; move a control onto a command instead"])
        #expect(CommandPathLimit.problems(baseline: header + "A.swift: Button(\"A\") {}\nA.swift: Button(\"B\") {}\n", name: "f.txt").isEmpty)
        #expect(CommandPathLimit.problems(baseline: header + "A.swift: Button(\"A\") {}\n", name: "f.txt").isEmpty)
        #expect(CommandPathLimit.problems(baseline: "# x\n# max: 0\n", name: "f.txt").isEmpty)
    }

    /// A baseline whose second line is not `# max: N` fails.
    @Test func headerIsRequired() {
        #expect(CommandPathLimit.problems(baseline: "# x\nA.swift: Button(\"A\") {}\n", name: "f.txt")
            == ["f.txt: its second line must be `# max: N`"])
        #expect(CommandPathLimit.problems(baseline: "# x\n# max: two\n", name: "f.txt")
            == ["f.txt: its second line must be `# max: N`"])
    }

    /// Each real baseline holds its limit.
    @Test(arguments: baselines)
    func baselineHoldsItsLimit(name: String) throws {
        let path = "Tests/command-path-baseline/\(name).txt"
        let text = try String(contentsOf: CommandPathTests.root.appendingPathComponent(path), encoding: .utf8)
        let problems = CommandPathLimit.problems(baseline: text, name: path)
        #expect(problems.isEmpty, "\(problems)")
    }
}
