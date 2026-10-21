// TimelineSelectAllTests.swift: TSA-1's ⌘A routing (timeline-select-all
// packet). While a strip has focus and its host passed onSelectAllKeys, the
// strip publishes a TimelineSelectAll whose run calls that closure once; with
// no focus, or no closure, it publishes nothing and ⌘A goes elsewhere.
// macOS only.
import Foundation
import SwiftUI
@testable import SuiteUI
import Testing

@MainActor @Suite struct TimelineSelectAllTests {
    @Test func focusedRouteWins() {
        var runs = 0
        let route = TimelineSelectAll.route(focused: true, onSelectAllKeys: { runs += 1 })
        #expect(route != nil)
        route?.run()
        #expect(runs == 1)
    }

    @Test func noRouteWithoutFocus() {
        var runs = 0
        let unfocused = TimelineSelectAll.route(focused: false, onSelectAllKeys: { runs += 1 })
        #expect(unfocused == nil)
        unfocused?.run()
        #expect(runs == 0)
        #expect(TimelineSelectAll.route(focused: true, onSelectAllKeys: nil) == nil)
    }
}
