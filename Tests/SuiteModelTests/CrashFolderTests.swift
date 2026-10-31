// CrashFolderTests.swift (report-problem RP-5b, written first): which crash folder the Report a Problem sheet
// reads and which of its files it opens. The folder is `~/Library/Logs/DiagnosticReports` unless the launch
// arguments name another with `-SuiteCrashDir <path>` (the Help journey's fixture folder). Of its entries only
// suite crash files (`.ips`, `.crash`) at most 7 days old are read, newest first and at most `CrashFolder.limit` of them, so a Mac full
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
            CrashFolder.Entry(name: "Design_2026-10-21-101010_Mac.crash", modified: Self.now - 100),
        ]
        #expect(CrashFolder.toRead(entries, now: Self.now).map(\.name)
            == ["Photo-newer.ips", "Design_2026-10-21-101010_Mac.crash", "Photo-older.ips", "Halo-edge.ips"])
    }

    @Test func atMostTheLimitAreRead() {
        let entries = (0..<(CrashFolder.limit + 10)).map { CrashFolder.Entry(name: "Photo-\($0).ips", modified: Self.now - Double($0)) }
        let read = CrashFolder.toRead(entries, now: Self.now)
        #expect(read.count == CrashFolder.limit)
        #expect(read.first?.name == "Photo-0.ips" && read.last?.name == "Photo-\(CrashFolder.limit - 1).ips")
    }

    /// On a busy Mac other apps' newer crashes never push the suite's out of the cap.
    @Test func otherAppsCrashesDontTakeTheCap() {
        let others = (0..<(CrashFolder.limit * 2)).map { CrashFolder.Entry(name: "Safari-\($0).ips", modified: Self.now - Double($0)) }
        let photo = CrashFolder.Entry(name: "Photo-2026-10-21-101010.ips", modified: Self.now - 3600)
        #expect(CrashFolder.toRead(others + [photo], now: Self.now).map(\.name) == [photo.name])
    }

    /// The reader lists a real folder: the suite's recent crash files, newest first, nothing else.
    @Test func theReaderReadsTheFolder() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("crash-folder-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["Photo-a.ips", "Halo_b_Mac.crash", "Safari-c.ips", "Photo-d.diag"] {
            try Data("Process: x".utf8).write(to: folder.appendingPathComponent(name))
        }
        let read = CrashFolderReader.read(folder: folder.path, now: Date())
        #expect(Set(read.map(\.name)) == ["Photo-a.ips", "Halo_b_Mac.crash"])
        #expect(read.allSatisfy { $0.text == "Process: x" })
        #expect(CrashFolderReader.read(folder: folder.path + "/missing", now: Date()).isEmpty)
    }

    @Test func anEmptyFolderReadsNothing() {
        #expect(CrashFolder.toRead([], now: Self.now).isEmpty)
    }
}
