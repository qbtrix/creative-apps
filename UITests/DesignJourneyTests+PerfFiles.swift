// DesignJourneyTests+PerfFiles.swift: files-history's perf journey P4
// (docs/blueprints/design/features/files-history.md, Journey steps item 4;
// FH-7; blueprint design section 4, P4, and 7.1, QD-S11). On `crowd` (2,000
// layers) with `-DesignSaveTo <tmp>`, ⌘S writes the file with no panel; the
// app quits and relaunches with `-DesignOpenFile <tmp>` until the window is
// named after the file and shows its canvas.
// QB-L9 is gated from the command (docs/review-rubric.md): the window marks
// `open-command` when its open begins and `progress-shown` when its
// "Opening <name>…" note shows, both on `design.open` in `suite.perf`, and
// the gap between them must be at most the rubric's 200 ms CI placeholder
// (100 ms is the target the report states). The rest is report-only (QB-L12;
// How gates are set): from the relaunch the test polls the window and times
// each poll's round trip, which needs the app's main thread to answer, so the
// longest is a coarse sign of a main-thread stall; the report also gives the
// progress and `open-landed` marks from the relaunch and, when Design
// publishes them, `suite.perf`'s frame intervals against QB-L12's 2
// refreshes. The numbers go to .build/ui-screens/perf-design-files.json and
// attach as "perf-design-files"; the test asserts that the saved file
// reopened, named after it (the launch file wins over `-DesignFixture`).
// Every flag carries a value (`-SuitePerfProbe YES`, as AfterGlow's journeys
// pass it): the launch arguments become UserDefaults' argument domain in
// "-key value" pairs, so a bare `-SuitePerfProbe` followed by `-DesignSaveTo
// <tmp>` took `-DesignSaveTo` as its value and left the path on its own, which
// AppKit opens as a file at launch instead of the first window (#3020: the
// launch showed a menu bar and no window). FrameProbe only looks for the flag.
import XCTest

final class DesignPerfFilesJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "crowd", "-SuiteWindowSize", "1024x768", "-SuitePerfProbe", "YES"]
    /// A poll round trip over this many milliseconds counts as a stall (QB-L12: 2 refreshes at 60 Hz).
    static let stallMilliseconds = 2 * 1000.0 / 60
    static let fileName = "crowd.design"
    /// QB-L9's CI placeholder: the open's progress shows within this many milliseconds of the command.
    static let progressGateMilliseconds = 200.0

    /// P4: save `crowd`, relaunch on the saved file; gate the progress from the command, report the rest.
    @MainActor func testOpenLargeFile() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "design-perf-files-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: Self.fileName)

        // Save: ⌘S writes exactly -DesignSaveTo's path, no panel.
        let saving = Self.arguments + ["-DesignSaveTo", file.path]
        let reopening = Self.arguments + ["-DesignOpenFile", file.path]
        for arguments in [saving, reopening] {
            XCTAssertEqual(Self.unpaired(arguments), [], "a launch argument without its flag opens as a file, not a window")
        }
        let design = Journey("Design", self, arguments: saving)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "crowd showed no page (suite.canvas)")
        design.press(character: "s", .command, step: "perf-files-saved")
        XCTAssert(waitForFile(file), "⌘S wrote no \(Self.fileName)")
        design.app.terminate()

        // Reopen: poll from the relaunch until the window is named after the file and shows its canvas.
        let launched = ProcessInfo.processInfo.systemUptime
        let reopened = Journey("Design", self, arguments: reopening)
        // The title carries the save state ("crowd.design – Saved", files-history FH-4), so match its start.
        let window = reopened.app.windows.matching(NSPredicate(format: "title BEGINSWITH %@", Self.fileName)).firstMatch
        let canvas = reopened.element("suite.canvas")
        var (polls, longest, stalls, shownMs, done) = (0, 0.0, 0, Double?.none, false)
        while !done, ProcessInfo.processInfo.systemUptime - launched < 120 {
            let started = ProcessInfo.processInfo.systemUptime
            done = window.exists && canvas.exists
            let trip = (ProcessInfo.processInfo.systemUptime - started) * 1000
            if done { shownMs = (ProcessInfo.processInfo.systemUptime - launched) * 1000 }
            polls += 1
            longest = max(longest, trip)
            if trip > Self.stallMilliseconds { stalls += 1 }
        }
        XCTAssert(done, "\(Self.fileName) didn't reopen within 120 s")
        reopened.shot("perf-files-reopened")

        let document = reopened.element("suite.perf").waitForExistence(timeout: 5) ? reopened.perf() : nil
        let command = document?.marks.first { $0.name == "open-command" }
        let progress = document?.marks.first { $0.name == "progress-shown" }
        XCTAssertNotNil(progress, "Design recorded no progress-shown mark for the opened file (FH-7)")
        if let command, let progress {
            let ms = (progress.time - command.time) * 1000
            XCTAssertLessThanOrEqual(ms, Self.progressGateMilliseconds,
                                     "\"Opening…\" showed \(Int(ms)) ms after the open began (QB-L9: target 100 ms)")
        } else {
            XCTFail("Design recorded no open-command mark, so QB-L9 can't be timed from the command")
        }
        report(document: document, launched: launched, shownMs: shownMs, polls: polls, longest: longest, stalls: stalls)
    }

    // MARK: - Steps

    /// The arguments that don't sit in a "-flag value" pair, read two at a time from the start as
    /// UserDefaults' argument domain reads them: a flag with no value, or a value with no flag.
    static func unpaired(_ arguments: [String]) -> [String] {
        stride(from: 0, to: arguments.count, by: 2).flatMap { index -> [String] in
            let flag = arguments[index]
            guard index + 1 < arguments.count else { return [flag] }
            let value = arguments[index + 1]
            return flag.hasPrefix("-") && !value.hasPrefix("-") ? [] : [flag, value]
        }
    }

    /// Waits up to ten seconds for `file` to exist on disk.
    @MainActor private func waitForFile(_ file: URL) -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: file.path) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return FileManager.default.fileExists(atPath: file.path)
    }

    /// Writes the report-only numbers to .build/ui-screens/perf-design-files.json and attaches them.
    @MainActor private func report(
        document: ProbeDocument?, launched: Double, shownMs: Double?, polls: Int, longest: Double, stalls: Int
    ) {
        let ms = { (value: Double) in String(format: "%.0f", value) }
        var numbers: [String: String] = [
            "QB-L12 P4 main-thread": "polls=\(polls) longest-ms=\(ms(longest)) over-\(ms(Self.stallMilliseconds))ms=\(stalls) "
                + "report-only (accessibility query round trips from the relaunch)",
        ]
        let canvas = shownMs.map { "canvas-shown-ms=\(ms($0))" } ?? "canvas never shown"
        let mark = { (name: String) in document?.marks.first { $0.name == name } }
        if let progress = mark("progress-shown") {
            let fromCommand = mark("open-command").map { "from-command-ms=\(ms((progress.time - $0.time) * 1000))" }
            let landed = mark("open-landed").map { "landed-from-relaunch-ms=\(ms(($0.time - launched) * 1000))" }
            numbers["QB-L9 P4 progress"] = [
                fromCommand ?? "no open-command mark", "progress-from-relaunch-ms=\(ms((progress.time - launched) * 1000))",
                landed ?? "no open-landed mark", canvas, "(target 100 ms, gate \(ms(Self.progressGateMilliseconds)) ms from the command)",
            ].joined(separator: " ")
        } else {
            numbers["QB-L9 P4 progress"] = "no progress-shown mark in suite.perf; \(canvas)"
        }
        if let document, !document.intervals.isEmpty {
            for (series, intervals) in document.intervals {
                numbers["QB-L12 \(series)"] = "p95 \(intervals.p95Refreshes) refreshes dropped=\(intervals.dropped) (gate 2, report-only)"
            }
        } else {
            numbers["QB-L12 frames"] = "no suite.perf frame intervals: Design's window doesn't publish them yet (#330, #333)"
        }
        for (key, value) in numbers.sorted(by: { $0.key < $1.key }) { print("\(key): \(value)") }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(numbers) else { return }
        // This file is UITests/DesignJourneyTests+PerfFiles.swift, so its grandparent is the repo root.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appending(path: ".build/ui-screens")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? json.write(to: folder.appending(path: "perf-design-files.json"))
        let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        attachment.name = "perf-design-files"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
