// CrashFolderTests.swift (report-problem RP-5b, written first): which crash folder the Report a Problem sheet
// reads and which of its files it opens. The folder is `~/Library/Logs/DiagnosticReports` unless the launch
// arguments name another with `-SuiteCrashDir <path>` (the Help journey's fixture folder). Of its entries only
// `.ips` files at most 7 days old are read, newest first and at most `CrashFolder.limit` of them, so a Mac full
// of old crash logs costs nothing. ProblemReport then keeps the suite's newest three.
import Foundation
import SuiteModel
import Testing

@Suite struct CrashFolderTests {
    static let now = Date(timeIntervalSince1970: 1_792_000_000)

    @Test func theFolderIsTheMacsDiagnosticReports() {
        #expect(CrashFolder.path(arguments: [], home: "/Users/tester") == "/Users/tester/Library/Logs/DiagnosticReports")
        #expect(CrashFolder.path(arguments: ["app"], home: "/Users/tester/") == "/Users/tester/Library/Logs/DiagnosticReports")
    }

    @Test func aJourneyNamesItsOwnFolder() {
        #expect(CrashFolder.path(arguments: ["app", "-SuiteCrashDir", "/tmp/crashes"], home: "/Users/tester") == "/tmp/crashes")
        #expect(CrashFolder.flag == "-SuiteCrashDir")
        #expect(CrashFolder.path(arguments: ["app", "-SuiteCrashDir"], home: "/h") == "/h/Library/Logs/DiagnosticReports",
                "a flag with no path falls back")
        #expect(CrashFolder.path(arguments: ["app", "-SuiteCrashDir", ""], home: "/h") == "/h/Library/Logs/DiagnosticReports",
                "an empty path falls back")
    }

    @Test func onlyRecentIpsFilesAreReadNewestFirst() {
        let entries = [
            CrashFolder.Entry(name: "Photo-older.ips", modified: Self.now - 7200),
            CrashFolder.Entry(name: "Photo-newer.ips", modified: Self.now - 60),
            CrashFolder.Entry(name: "Halo-stale.ips", modified: Self.now - 8 * 86_400),
            CrashFolder.Entry(name: "Halo-edge.ips", modified: Self.now - 7 * 86_400),
            CrashFolder.Entry(name: "Photo.diag", modified: Self.now - 30),
            CrashFolder.Entry(name: "Retired", modified: Self.now - 10),
        ]
        #expect(CrashFolder.toRead(entries, now: Self.now).map(\.name) == ["Photo-newer.ips", "Photo-older.ips", "Halo-edge.ips"])
    }

    @Test func atMostTheLimitAreRead() {
        let entries = (0..<(CrashFolder.limit + 10)).map { CrashFolder.Entry(name: "Other-\($0).ips", modified: Self.now - Double($0)) }
        let read = CrashFolder.toRead(entries, now: Self.now)
        #expect(read.count == CrashFolder.limit)
        #expect(read.first?.name == "Other-0.ips" && read.last?.name == "Other-\(CrashFolder.limit - 1).ips")
    }

    @Test func anEmptyFolderReadsNothing() {
        #expect(CrashFolder.toRead([], now: Self.now).isEmpty)
    }
}
