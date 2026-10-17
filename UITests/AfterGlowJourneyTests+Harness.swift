// AfterGlowJourneyTests+Harness.swift: the suite's journey harness (HM-0,
// blueprint suite.md 4.1). Compiled only into AfterGlowJourneyTests (its
// `${target_name}*.swift` glob), which also compiles SuiteModel's Values, so
// it can name a `SuiteApp`; a `Journey+Suite.swift` would compile into every
// app's bundle, which can't.
//
// A journey makes one `SuiteHarness` per test. `launch(fixture:)` starts
// `.build/apps/AfterGlow.app` (scripts/bundle-apps) by path with the suite
// flags: a fresh `-SuiteSupportDir` under the runner's temporary folder,
// `-SuiteFixture <name>` (the launcher seeds the store before its first
// frame, LauncherRouter+Services.swift), `-SuiteFixtureDocuments` pointing at
// UITests/Fixtures/suite (read only for the fixtures with documents),
// `-SuiteSkipOnboarding YES` and `-ApplePersistenceIgnoreState YES`.
// `attach(_:)` drives a running suite process by its bundle id and shoots and
// audits it under its own key: `afterglow` for the launcher, the app's raw
// value (`flare`, ...) for an embedded app. Only the `afterglow` counts are
// attached ("counts-afterglow", by the class's last test), so this bundle
// never overwrites an app bundle's counts in audit-counts.json. The
// harness's teardown terminates every suite process, launched, attached or
// started by the launcher, fails when one survives, and removes the folder.
import AppKit
import XCTest

extension Journey {
    /// A journey over one suite process that shoots and audits under
    /// `auditKey`. With `bundlePath` it drives the bundle at that path (to
    /// launch it); nil drives the process running as `bundleID`. It neither
    /// launches nor activates the app.
    init(bundlePath: String?, bundleID: String, auditKey: String, _ test: XCTestCase) {
        app = bundlePath.map { XCUIApplication(url: URL(fileURLWithPath: $0)) }
            ?? XCUIApplication(bundleIdentifier: bundleID)
        name = auditKey
        self.test = test
        test.continueAfterFailure = false
    }
}

@MainActor
final class SuiteHarness {
    /// The launcher's audit key, the `afterglow` line of UITests/audit-baseline.json.
    static let launcherKey = "afterglow"

    /// This file is UITests/<name>, so its grandparent is the repo root.
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    static let bundle = root.appending(path: ".build/apps/AfterGlow.app")
    static let fixtureDocuments = root.appending(path: "UITests/Fixtures/suite")

    let test: XCTestCase
    /// This test's suite store, passed as `-SuiteSupportDir`.
    let support: URL
    private var touched: [String: XCUIApplication] = [:]
    private var launcher: Journey?

    /// Makes the test's support folder and registers the teardown that ends every suite process.
    init(_ test: XCTestCase) {
        self.test = test
        support = FileManager.default.temporaryDirectory.appending(path: "afterglow-journey-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let isLast = test.name == type(of: test).defaultTestSuite.tests.last?.name
        test.addTeardownBlock { @MainActor () async -> Void in self.tearDown(attachingCounts: isLast) }
    }

    /// The audit key `app`'s shots count under.
    static func auditKey(_ app: SuiteApp) -> String {
        app == .launcher ? launcherKey : app.rawValue
    }

    /// The suite launch flags for `fixture` over `support` (blueprint 4.1).
    static func flags(fixture: String, support: URL) -> [String] {
        [
            "-ApplePersistenceIgnoreState", "YES", "-SuiteSupportDir", support.path,
            "-SuiteSkipOnboarding", "YES", "-SuiteFixture", fixture,
            "-SuiteFixtureDocuments", fixtureDocuments.path,
        ]
    }

    /// Launches AfterGlow.app fresh on `fixture` with the suite flags and
    /// `arguments` (`-SuitePerfProbe YES` to read suite.controls), after
    /// ending any suite process left running. Shoots under `afterglow`.
    @discardableResult
    func launch(fixture: String, arguments: [String] = []) -> Journey {
        endEverySuiteProcess()
        let journey = Journey(
            bundlePath: Self.bundle.path, bundleID: SuiteApp.launcher.bundleID, auditKey: Self.launcherKey, test)
        journey.app.launchArguments = Self.flags(fixture: fixture, support: support) + arguments
        settle()
        journey.app.launch()
        journey.app.activate()
        touched[SuiteApp.launcher.bundleID] = journey.app
        launcher = journey
        return journey
    }

    /// Drives the running `app` by its bundle id, brought to the front,
    /// shooting and auditing under its own key (`auditKey(_:)`). Fails when
    /// it isn't running within 30 seconds.
    func attach(_ app: SuiteApp) -> Journey {
        let journey = Journey(bundlePath: nil, bundleID: app.bundleID, auditKey: Self.auditKey(app), test)
        let deadline = Date(timeIntervalSinceNow: 30)
        while journey.app.state == .notRunning, Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
        }
        XCTAssert(journey.app.state != .notRunning, "\(app.displayName) (\(app.bundleID)) isn't running to attach to")
        journey.app.activate()
        XCTAssert(journey.app.windows.firstMatch.waitForExistence(timeout: 10), "\(app.displayName) shows no window")
        touched[app.bundleID] = journey.app
        if app == .launcher { launcher = journey }
        return journey
    }

    /// Ends every suite process, fails when one is still running 10 seconds
    /// later, removes the support folder and, after the class's last test,
    /// attaches the launcher's audit counts.
    private func tearDown(attachingCounts: Bool) {
        if attachingCounts { launcher?.auditCounts() }
        endEverySuiteProcess()
        let survivors = SuiteApp.allCases.filter { !running($0).isEmpty }
        XCTAssert(survivors.isEmpty, "suite processes survived the test: \(survivors.map(\.bundleID))")
        try? FileManager.default.removeItem(at: support)
    }

    /// Terminates every process this harness drove and every running suite
    /// app, then waits up to 10 seconds for them all to be gone.
    private func endEverySuiteProcess() {
        for app in SuiteApp.allCases where touched[app.bundleID] != nil || !running(app).isEmpty {
            let proxy = touched[app.bundleID] ?? XCUIApplication(bundleIdentifier: app.bundleID)
            if proxy.state != .notRunning { proxy.terminate() }
        }
        let deadline = Date(timeIntervalSinceNow: 10)
        while SuiteApp.allCases.contains(where: { !running($0).isEmpty }), Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
        }
    }

    /// The live processes of `app`; the run loop updates the list, so callers spin it.
    private func running(_ app: SuiteApp) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).filter { !$0.isTerminated }
    }

    /// Waits, up to four seconds, for the main screen's visible frame to
    /// read the same three times running: the Dock has settled after the
    /// last quit (Journey.swift says why).
    private func settle() {
        var previous = NSScreen.screens.first?.visibleFrame, steady = 0
        for _ in 0..<16 where steady < 3 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
            let frame = NSScreen.screens.first?.visibleFrame
            steady = frame == previous ? steady + 1 : 0
            previous = frame
        }
    }
}
