// SuiteJourneyTests+ListPoints.swift: how the list journeys (SuiteJourneyTests+Lists.swift, +ListMenus.swift) act on
// rows and cells. Clicking an element itself makes XCUITest ask for its hit point and scroll the gallery page's
// ScrollView to it, and on the runner that fails with "Unable to find hit point for ScrollView" (#2837, #2838, #2865).
// The journeys click the element's middle as a coordinate instead, and read "on screen" from frames, not isHittable
// (#2864).
import XCTest

extension XCUIElement {
    /// The element's middle, to click, double-click, right-click or hover without a scroll to visible.
    @MainActor var listMiddle: XCUICoordinate { coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)) }

    /// The element exists and its middle lies inside `area`'s frame.
    @MainActor func listShows(in area: XCUIElement) -> Bool {
        guard exists else { return false }
        let box = frame
        return !box.isEmpty && area.frame.contains(CGPoint(x: box.midX, y: box.midY))
    }
}
