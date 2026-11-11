// Journey+Frontmost.swift: waits for an app to come to the front, for the suite-menus journeys' Switch To ▸ Home
// step. Every <X>JourneyTests target compiles it (project.yml). It waits through XCTWaiter, which runs the main
// run loop: NSWorkspace's app properties only update while that loop runs in a common mode, so a
// `Thread.sleep` poll keeps reading the app that was in front before the switch.
import AppKit
import XCTest

extension XCTestCase {
    /// True once the app with `bundleID` is frontmost, within `timeout` seconds.
    @MainActor func waitForFrontmost(_ bundleID: String, timeout: TimeInterval) -> Bool {
        let front = NSPredicate { _, _ in NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID }
        return XCTWaiter.wait(for: [expectation(for: front, evaluatedWith: nil)], timeout: timeout) == .completed
    }
}
