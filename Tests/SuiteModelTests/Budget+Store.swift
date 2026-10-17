// Budget+Store.swift: QB-SM6, the store under its lock across two processes
// (blueprint 7.1). On Linux the test binary relaunches itself twice with
// `Process`, the children (marked by SUITE_STORE_WRITER) each note 500
// recents through StoreRecents into one temp folder, and the parent checks
// that no write was lost. Elsewhere (the macOS runner hosts the tests in
// another binary) two StoreRecents run on two tasks instead; each update
// opens its own lock fd, so flock serialises them the same way.
//
// The packet's QB-SM6 row: recents.json ends at revision 1,000 and holds the
// 200 newest of the 1,000 distinct notes (RecentsList.cap is 200). Each update
// reads the revision under the lock and writes it + 1, so a lost write leaves
// it short.
import Foundation
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(5))) struct StoreBudgetTests {
    static let perWriter = 500
    static let base = Date(timeIntervalSince1970: 1_800_000_000)

    /// One writer's 500 notes; writer k's item i is used at base + 2i + k, so all 1,000 dates differ.
    static func write(folder: String, writer k: Int) async throws -> Duration {
        let recents = StoreRecents(store: FileStore(folder: folder))
        let costs = try await suiteMeasure("store.note writer \(k)", runs: perWriter, budget: suiteBudget(device: 5)) { i in
            let path = "/tmp/Documents/w\(k)-\(i).design"
            let ref = SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .design,
                                       type: .designDocument, displayName: "w\(k)-\(i).design")
            try await recents.note(ref, event: .opened, at: base + Double(2 * i + k), thumbnail: nil)
        }
        let median = suiteMedian(costs)
        let micros = median.components.seconds * 1_000_000 + median.components.attoseconds / 1_000_000_000_000
        try String(micros).write(toFile: folder + "/median-\(k).txt", atomically: true, encoding: .utf8)
        return median
    }

    @Test func twoProcessesLoseNothing() async throws {
        let env = ProcessInfo.processInfo.environment
        if let child = env["SUITE_STORE_WRITER"], let bar = child.lastIndex(of: "|"), let k = Int(child[child.index(after: bar)...]) {
            _ = try await Self.write(folder: String(child[..<bar]), writer: k)
            return
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("StoreBudget-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        #if os(Linux)
        let children = try (0..<2).map { k in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            p.arguments = ["--testing-library", "swift-testing", "--filter", "StoreBudgetTests/twoProcessesLoseNothing"]
            p.environment = env.merging(["SUITE_STORE_WRITER": "\(folder)|\(k)"]) { $1 }
            let log = folder + "/writer-\(k).log"   // the child's test output, shown only when it fails
            _ = FileManager.default.createFile(atPath: log, contents: nil)
            p.standardOutput = FileHandle(forWritingAtPath: log)
            p.standardError = FileHandle(forWritingAtPath: log)
            try p.run()
            return (p, log)
        }
        for (p, log) in children {
            p.waitUntilExit()
            #expect(p.terminationStatus == 0, "\((try? String(contentsOfFile: log, encoding: .utf8)) ?? "")")
        }
        #else
        async let a = Self.write(folder: folder, writer: 0)
        async let b = Self.write(folder: folder, writer: 1)
        _ = try await (a, b)
        #endif
        let (list, revision) = try FileStore(folder: folder).read("recents.json", as: RecentsList.self)
        #expect(revision == 2 * Self.perWriter)
        #expect(list?.revision == 2 * Self.perWriter)
        let newest = (0..<2 * Self.perWriter).reversed().prefix(RecentsList.cap).map { n in "w\(n % 2)-\(n / 2).design" }
        #expect(list?.items.map(\.ref.displayName) == Array(newest))
        for k in 0..<2 {
            let micros = Int((try? String(contentsOfFile: folder + "/median-\(k).txt", encoding: .utf8)) ?? "") ?? Int.max
            print("SuiteBudget QB-SM6 writer \(k) median \(micros) µs")
            #expect(Duration.microseconds(micros) <= suiteBudget(device: 5))
        }
    }
}
