// Journey+Stress.swift: the two gestures the <X>StressPerfJourneyTests (the beta quality gate on complex files)
// share, on top of Journey.health (Journey+Health.swift): `timed`, one action's round trip for a gesture with no
// `suite.perf` series (Select All, an undo, a click), and `drag`, a press, a ~3 s drag at a steady speed and a
// release, the way the real-perf journeys drag. The stress journeys run only under `scripts/ui-test perf`.
import AppKit
import XCTest

extension Journey {
    /// Runs `body` once; its round trip in seconds, for `health`'s report-only steps.
    static func timed(_ body: () -> Void) -> [Double] {
        let started = Date()
        body()
        return [Date().timeIntervalSince(started)]
    }

    /// Presses `from`, drags to `to` over about `seconds` and lets go; `distance` is the drag's length in points.
    static func drag(_ from: XCUICoordinate, to: XCUICoordinate, distance: CGFloat, seconds: Double = 3) {
        let scale = NSScreen.main?.backingScaleFactor ?? 1
        from.click(forDuration: 0.05, thenDragTo: to, withVelocity: XCUIGestureVelocity(distance * scale / seconds),
                   thenHoldForDuration: 0.05)
    }
}
