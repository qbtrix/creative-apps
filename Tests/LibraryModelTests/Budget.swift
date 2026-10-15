// Budget.swift: Library's shared timing helper. `measure` runs a body a few
// times, prints one `LIBRARY-BUDGET <area> <row> median=… p95=…` line and
// appends it to `.build/snapshots/library-budget-<area>.txt`, where the first
// word of `name` is the area. A failed write is ignored: the test still judges.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

enum Budget {
    /// Times `body` `runs` times; the median and p95 are in milliseconds.
    @discardableResult
    static func measure(_ name: String, runs: Int = 20, _ body: () -> Void) -> (median: Double, p95: Double) {
        let clock = ContinuousClock()
        let count = max(runs, 1)
        let costs = (0..<count).map { _ in milliseconds(clock.measure(body)) }.sorted()
        let median = costs[(count - 1) / 2]
        let p95 = costs[min(count - 1, (count * 95 + 99) / 100 - 1)]
        let line = "LIBRARY-BUDGET \(name) median=\(rounded(median)) p95=\(rounded(p95))"
        print(line)
        append(line, area: name.split(separator: " ").first.map(String.init) ?? "library")
        return (median, p95)
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
    }

    private static func rounded(_ value: Double) -> String {
        String(Double(Int((value * 1_000).rounded())) / 1_000)
    }

    private static func append(_ line: String, area: String) {
        let folder = URL(fileURLWithPath: ".build/snapshots", isDirectory: true)
        let file = folder.appendingPathComponent("library-budget-\(area).txt")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let earlier = (try? Data(contentsOf: file)) ?? Data()
            try (earlier + Data((line + "\n").utf8)).write(to: file)
        } catch {
            // Ignored: the budget line is a convenience; the test's #expect judges.
        }
    }
}
