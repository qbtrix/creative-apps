// Journey+Health.swift: the real-app perf checks every journey bundle compiles
// (project.yml's Journey template takes UITests/Journey*.swift). The
// <X>RealPerfJourneyTests classes launch the bundled app on a large document,
// drive one gesture for about 3 s, and judge it the way a person at the Mac
// would feel it:
//   - step: the `suite.perf` samples the gesture added under its series
//     (event time to the main-actor turn or refresh that showed it, recorded
//     by the app under -SuitePerfProbe), p95 in ms against `stepBudget`. A
//     series the app doesn't publish reads n/a; a gesture with no series
//     (scroll, zoom keys) reports each XCUITest call's round trip, which
//     carries XCUITest's own overhead, so neither is gated.
//   - hang: a window query through XCUITest (the accessibility path) timed
//     right after the gesture; over `hangLimit` seconds fails.
//   - surfaces and idle, from outside the process: macOS sandboxes the test
//     runner, so it can't start /usr/bin/sample or ps itself. It drops
//     `<id>.req` (the app's pid) in its container's tmp/realperf/, waits for
//     scripts/realperf-watch (which `scripts/ui-test perf` runs next to
//     xcodebuild) to take it, drives the gesture while that samples the pid
//     for 3 s, then drops `<id>.done` and reads .build/realperf/<id>.json:
//     scripts/sample-surfaces' verdict (over 20 percent of
//     main-thread samples under an IOSurface allocation fails) and the CPU 3 s
//     after the gesture, twice over one second (both over `idleLimit` fails).
// The journeys launch a copy of the bundled app with its own bundle id
// (`Health.bundle`, made by `scripts/ui-test perf`), so a copy of the app
// the user has open never blocks the launch, and terminate it at the end. It
// is found by pid among the running apps whose bundle is that copy, never by
// name, so an app the user runs is never sampled or touched. Each
// gesture's line is printed (xcodebuild's log) and attached as
// "realperf-<app>-<gesture>". Callers set continueAfterFailure, so every
// gesture reports even after one fails.
import AppKit
import XCTest

/// The limits the real-app checks hold every gesture to.
enum Health {
    static let stepBudget = 33.0      // ms, p95 of a gesture's steps at 8K
    static let idleLimit = 10.0       // percent CPU
    static let idleWait = 3.0         // seconds after the gesture
    static let hangLimit = 2.0        // seconds for an accessibility answer
    /// Where scripts/realperf-watch writes its verdicts, and where `scripts/ui-test perf` puts the 8K photo.
    @MainActor static var out: URL { Journey.repoRoot.appending(path: ".build/realperf") }
    /// `scripts/ui-test perf` copies the bundled AfterGlow.app here and gives each helper app the
    /// bundle id `<id>.realperf`, so the journeys launch the same build while the user's own copy of
    /// that app runs (XCUITest can't launch a second instance of a running bundle id).
    @MainActor static func bundle(_ appName: String) -> URL {
        out.appending(path: "AfterGlow.app/Contents/Helpers/\(appName).app")
    }
}

extension Journey {
    /// This worktree's repo root (UITests/Journey+Health.swift's grandparent).
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// The pid of `appName`'s real-perf copy this journey launched: the running
    /// app whose bundle resolves to `Health.bundle(appName)`, the newest if several.
    func pid(of appName: String) -> pid_t? {
        let path = Health.bundle(appName).resolvingSymlinksInPath().path
        return NSWorkspace.shared.runningApplications
            .filter { $0.bundleURL?.resolvingSymlinksInPath().path == path }
            .max { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }?
            .processIdentifier
    }

    /// Launches `<appName>`'s real-perf copy (`Health.bundle`), terminated at the test's end.
    static func realPerf(_ appName: String, _ test: XCTestCase, arguments: [String]) -> Journey {
        let journey = Journey(appName, test, arguments: arguments, bundle: Health.bundle(appName))
        test.continueAfterFailure = true
        // The runner waits in the background while the sidecar works; keep App Nap from stretching those waits.
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "real-perf journey")
        nonisolated(unsafe) let token = activity
        test.addTeardownBlock { ProcessInfo.processInfo.endActivity(token) }
        nonisolated(unsafe) let app = journey.app
        test.addTeardownBlock { @MainActor in app.terminate() }
        return journey
    }

    /// Runs `gesture` with every health check on the app `pid`, reports one
    /// line for `label` and fails each check that misses its limit. `series`
    /// is the `suite.perf` series the gesture's steps record under; nil when
    /// `gesture` returns its own step times (round trips, report-only).
    @discardableResult
    func health(_ label: String, pid: pid_t, series: String?, gesture: () -> [Double]) -> String {
        let before = series.map { probeSamples($0).count } ?? 0
        let inbox = FileManager.default.temporaryDirectory.appending(path: "realperf")
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let id = "\(name)-\(slug(label))-\(UUID().uuidString.prefix(8))"
        let request = inbox.appending(path: "\(id).req")
        try? Data("\(pid)\n".utf8).write(to: request)
        let taken = Self.waitUntil(5) { !FileManager.default.fileExists(atPath: request.path) }
        XCTAssert(taken, "\(label): no scripts/realperf-watch took \(request.path); run these through scripts/ui-test perf")

        let started = Date()
        let roundTrips = gesture()
        var parts = [String(format: "gesture %.1f s", Date().timeIntervalSince(started))]
        // Hang first, before the reads below, which a hung app would stall.
        let asked = Date()
        _ = app.windows.firstMatch.exists
        let answer = Date().timeIntervalSince(asked)
        parts.append(String(format: "ax answer %.2f s (limit %.0f s)", answer, Health.hangLimit))
        XCTAssertLessThanOrEqual(answer, Health.hangLimit, "\(label): the app took \(answer) s to answer an accessibility query")
        try? Data().write(to: inbox.appending(path: "\(id).done"))

        if taken {
            let file = Health.out.appending(path: "\(id).json")
            if Self.waitUntil(180, { FileManager.default.fileExists(atPath: file.path) }),
                let data = try? Data(contentsOf: file),
                let verdict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let surface = verdict["surface"] as? String ?? "no verdict"
                parts.append(surface.components(separatedBy: "\n").first ?? surface)
                print("realperf \(name) \(label) sample (\(verdict["sample_file"] ?? "")):\n\(surface)")
                XCTAssertEqual(verdict["surface_status"] as? Int, 0, "\(label): \(surface)")
                let idle = (verdict["idle"] as? [Any] ?? []).compactMap { $0 as? Double }
                parts.append("idle cpu " + idle.map { String(format: "%.0f%%", $0) }.joined(separator: "/")
                             + String(format: " (limit %.0f%%)", Health.idleLimit))
                XCTAssertEqual(idle.count, 2, "\(label): realperf-watch read no CPU for pid \(pid)")
                if let lowest = idle.min() {
                    XCTAssertLessThanOrEqual(lowest, Health.idleLimit, "\(label): \(Int(lowest))% CPU \(Health.idleWait) s after the gesture stopped")
                }
            } else {
                parts.append("no realperf-watch verdict")
                XCTFail("\(label): scripts/realperf-watch wrote no \(file.path)")
            }
        }

        if let series {
            let steps = probeSamples(series).dropFirst(before).map { ($0.shownAt - $0.eventTime) * 1000 }
            let p95 = Self.p95(steps)
            parts.insert(String(format: "steps %d p95 %@ ms (budget %.0f ms, %@)", steps.count,
                                p95.map { String(format: "%.0f", $0) } ?? "n/a", Health.stepBudget, series), at: 0)
            if let p95 { XCTAssertLessThanOrEqual(p95, Health.stepBudget, "\(label): step p95 \(Int(p95)) ms over \(Int(Health.stepBudget)) ms") }
        } else {
            let p95 = Self.p95(roundTrips.map { $0 * 1000 })
            parts.insert(String(format: "steps %d round-trip p95 %@ ms (report-only)", roundTrips.count,
                                p95.map { String(format: "%.0f", $0) } ?? "n/a"), at: 0)
        }

        let line = "realperf \(name) \(label): " + parts.joined(separator: " | ")
        print(line)
        let attachment = XCTAttachment(string: line)
        attachment.name = "realperf-\(name)-\(slug(label))"
        attachment.lifetime = .keepAlways
        test.add(attachment)
        return line
    }

    /// Polls `condition` every 0.1 s for up to `seconds`; whether it held.
    static func waitUntil(_ seconds: Double, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(seconds)
        while !condition() {
            guard Date() < end else { return false }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return true
    }

    /// Drags `element` (a slider) from 10% to 90% and back for about `seconds` in all.
    func scrub(_ element: XCUIElement, seconds: Double = 3) {
        let width = element.frame.width, scale = NSScreen.main?.backingScaleFactor ?? 1
        let velocity = XCUIGestureVelocity(width * 0.8 * scale / (seconds / 2))
        for (from, to) in [(0.1, 0.9), (0.9, 0.1)] {
            element.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.5)).click(
                forDuration: 0.05, thenDragTo: element.coordinate(withNormalizedOffset: CGVector(dx: to, dy: 0.5)),
                withVelocity: velocity, thenHoldForDuration: 0.05)
        }
    }

    /// Scrolls the inspector until `element` is hittable (at most ten tries).
    func reveal(_ element: XCUIElement) {
        let inspector = self.element("suite.inspector")
        for _ in 0..<10 where !element.isHittable {
            inspector.scroll(byDeltaX: 0, deltaY: element.frame.midY > inspector.frame.midY ? -120 : 120)
        }
    }

    /// The `suite.perf` samples of `series` so far, in order; empty without the probe.
    func probeSamples(_ series: String) -> [ProbeSample] {
        let probe = element("suite.perf")
        guard probe.exists, let document = try? JSONDecoder().decode(ProbeDocument.self, from: Data(probe.label.utf8))
        else { return [] }
        return document.samples.filter { $0.series == series }
    }

    /// Calls `body` with a step number until `seconds` pass; each call's round trip, in seconds.
    static func repeatFor(seconds: Double, _ body: (Int) -> Void) -> [Double] {
        var times = [Double](), step = 0
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            let started = Date()
            body(step)
            times.append(Date().timeIntervalSince(started))
            step += 1
        }
        return times
    }

    /// The nearest-rank 95th percentile; nil when empty.
    static func p95(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[min(sorted.count, Int((0.95 * Double(sorted.count)).rounded(.up))) - 1]
    }
}
