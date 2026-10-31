// ProblemReportTests.swift (report-problem RP-1, written first; RP-4 turned them on): MJ-RP's report rules on
// fixture crash files. Only suite processes, newest first, at most three, none older than 7 days; no home path,
// user or host string survives anywhere in the text; a report with no crashes says so. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct ProblemReportTests {
    static let now = Date(timeIntervalSince1970: 1_792_000_000)
    static let home = "/Users/tester", user = "tester", host = "testers-mac"

    /// A crash file `days` old: an `.ips` header line naming the process, then a body whose crashed thread
    /// and binary images carry the home path, the user and the host.
    static func crash(_ name: String, days: Double, process: String) -> CrashFile {
        let header = #"{"app_name":"\#(process)","name":"\#(process)","bug_type":"309"}"#
        let body = """
        {"procPath":"/Users/tester/Applications/AfterGlow.app/Contents/MacOS/\(process)",
        "exception":{"type":"EXC_BAD_ACCESS","signal":"SIGSEGV"},
        "faultingThread":0,"threads":[{"triggered":true,"frames":[{"symbol":"crashHere"}]},{"frames":[{"symbol":"idle"}]}],
        "userName":"TESTER","hostName":"Testers-Mac","usedImages":[{"path":"/Users/tester/Library/Frameworks/X"}]}
        """
        return CrashFile(name: name, modified: now.addingTimeInterval(-days * 86_400), text: header + "\n" + body)
    }

    /// Two Photo crashes, one from another app, one 10-day-old Halo crash and one launcher crash.
    static let fixture: [CrashFile] = [
        crash("Photo-2026-10-19-101010.ips", days: 2, process: "Photo"),
        crash("Safari-2026-10-20-090000.ips", days: 1, process: "Safari"),
        crash("Halo-2026-10-11-080000.ips", days: 10, process: "Halo"),
        crash("Photo-2026-10-20-121212.ips", days: 1, process: "Photo"),
        crash("AfterGlow-2026-10-18-070000.ips", days: 3, process: "AfterGlow"),
        crash("Design-2026-10-17-070000.ips", days: 4, process: "Design"),
    ]

    static func report(_ crashes: [CrashFile] = fixture) -> ProblemReport {
        ProblemReport.build(app: .photo, version: "0.9.0", build: "412", macOS: "26.1", model: "Mac16,1",
                            crashes: crashes, now: now, home: home, user: user, host: host)
    }

    @Test func keepsTheAppAndSystemFields() {
        let report = Self.report()
        #expect(report.app == "Photo" && report.version == "0.9.0" && report.build == "412")
        #expect(report.macOS == "26.1" && report.model == "Mac16,1")
    }

    @Test func onlySuiteCrashes() {
        let crashes = Self.report().crashes
        #expect(crashes.count == 3)
        let order = ["Photo-2026-10-20-121212", "Photo-2026-10-19-101010", "AfterGlow-2026-10-18"]
        #expect(zip(crashes, order).allSatisfy { $0.contains($1) }, "newest suite crash first")
        #expect(!crashes.contains { $0.contains("Safari") }, "another app's crash never enters the report")
        #expect(!crashes.contains { $0.contains("Design-2026-10-17") }, "the fourth suite crash is dropped")
    }

    @Test func onlyRecentCrashes() {
        let crashes = Self.report().crashes
        #expect(!crashes.contains { $0.contains("Halo") })
        #expect(Self.report([Self.crash("Halo-old.ips", days: 7.5, process: "Halo")]).crashes.isEmpty)
    }

    @Test func keepsTheCrashedThreadOnly() {
        let crash = Self.report([Self.fixture[0]]).crashes.first ?? ""
        #expect(crash.contains("EXC_BAD_ACCESS") && crash.contains("crashHere"))
        #expect(!crash.contains("idle"), "a thread that didn't crash is trimmed away")
    }

    @Test func redactsEveryOccurrence() {
        let note = "It crashed in /Users/tester/Pictures on testers-mac, tester here. Again in /Users/Tester/Desktop "
            + "on TESTERS-MAC, Tester again."
        let text = Self.report().text(note: note)
        #expect(!text.contains("/Users/"))
        #expect(!text.lowercased().contains("tester"), "the user and host names go, in any case")
        #expect(text.contains("~/"), "the home path reads as ~")
        #expect(text.contains("<user>") && text.contains("<host>"))
        for crash in Self.report().crashes { #expect(!crash.lowercased().contains("tester") && !crash.contains("/Users/")) }
    }

    @Test func textPutsTheNoteFirstThenTheReport() {
        let text = Self.report().text(note: "The brush lagged.")
        #expect(text.hasPrefix("The brush lagged."))
        for field in ["Photo", "0.9.0", "412", "26.1", "Mac16,1"] { #expect(text.contains(field)) }
    }

    @Test func aReportWithNoCrashesSaysSo() {
        let report = Self.report([])
        #expect(report.crashes.isEmpty)
        #expect(report.text(note: "").lowercased().contains("no crash"))
    }

    @Test func roundTripsAsJSON() throws {
        let report = Self.report()
        let data = try JSONEncoder().encode(report)
        #expect(try JSONDecoder().decode(ProblemReport.self, from: data) == report)
    }

    /// The packet keeps `.ips` (and `.crash`) files: an older plain-text `.crash` names its process on a
    /// `Process:` line and is redacted like the rest.
    @Test func readsCrashFilesToo() {
        let text = """
        Process:               Photo [4242]
        Path:                  /Users/tester/Applications/AfterGlow.app/Contents/MacOS/Photo
        Exception Type:        EXC_BAD_ACCESS (SIGSEGV)
        """
        let crash = CrashFile(name: "Photo_2026-10-21-101010_testers-mac.crash", modified: Self.now - 3600, text: text)
        let other = CrashFile(name: "Safari_2026-10-21-101010_testers-mac.crash", modified: Self.now - 60,
                              text: "Process:               Safari [1]")
        let crashes = Self.report([crash, other]).crashes
        #expect(crashes.count == 1 && crashes.first?.contains("EXC_BAD_ACCESS") == true, "the Photo .crash isn't read")
        #expect(!crashes.contains { $0.lowercased().contains("tester") || $0.contains("/Users/") })
    }

    /// A report that knows no version or build (a CLI run outside AfterGlow.app) leaves them out, never "Photo  ()".
    @Test func anUnknownVersionIsLeftOut() {
        let report = ProblemReport(app: "Photo", version: "", build: "", macOS: "26.1", model: "", crashes: [])
        let text = report.text(note: "")
        #expect(text.hasPrefix("Photo\nmacOS 26.1\n\nNo crash"), "\(text)")
        #expect(!text.contains("()") && !text.contains("Mac \n"))
    }
}
