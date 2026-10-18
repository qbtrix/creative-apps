// ListBudgetTests.swift: the list's quality budgets that run without a window
// (lists-and-layers packet, Quality tests). QB-S14: SuiteListEditing.reordered
// over 10,000 ids costs at most 1 ms, gated at 10 ms for debug builds. The
// best of several runs is gated, so a busy machine doesn't fail it. LL-3 adds
// QB-S12's grid extend here. No SwiftUI. macOS only.
import Foundation
import SuiteUI
import Testing

@Suite struct ListBudgetTests {
    @Test func reorderWithinBudget() {
        let editing = SuiteListEditing()
        let order = Array(0..<10_000)
        var best = Duration.seconds(1)
        var moved: [Int] = []
        for _ in 0..<20 {
            let elapsed = ContinuousClock().measure {
                moved = editing.reordered(order, moving: 9_999, to: 0)
            }
            best = min(best, elapsed)
        }
        #expect(moved.count == order.count)
        #expect(moved.first == 9_999)
        #expect(best <= .milliseconds(10), "QB-S14: \(best) to reorder 10,000 ids (target 1 ms)")
    }
}
