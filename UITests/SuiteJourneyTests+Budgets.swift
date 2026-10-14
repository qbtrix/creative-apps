// SuiteJourneyTests+Budgets.swift: SuiteUI's perf journey gates, the
// placeholders of blueprint suiteui section 7.1 (QB-S1 to QB-S10). Every row
// is report-only: `Journey.perf()` (Journey+Input.swift) reads these through
// `PerfBudgeted` and attaches each measured series against its gate as
// "perf-budgets-<test>". After ten green runs on `dev`, setting a gate is a
// one-line PR here: the measured p95 as `limit`, and `enforced: true`. A gate
// never loosens without the captain. The device targets (p95 ≤ 2 or ≤ 1
// frames late, ≤ 1.5 refreshes) are 7.1's; the limits below are its CI
// placeholders. Each perf test lives in the journey file of the feature that
// owns its page (blueprint 4.4) and calls `perf()`.
import XCTest

extension SuiteJourneyTests: PerfBudgeted {
    /// QB-S1, SP1: bar slider and exact field drag, frames late (target p95 ≤ 2).
    static let barSliderDrag = PerfBudget(row: "QB-S1", series: ["bar-slider", "exact-field"], measure: .latency, limit: 3)
    /// QB-S2, SP6: bar slider arrow key to the new value drawn (target p95 ≤ 1).
    static let sliderKey = PerfBudget(row: "QB-S2", series: ["slider-key"], measure: .latency, limit: 2)
    /// QB-S3, SP2: canvas drag and Space-pan (target p95 ≤ 2).
    static let canvasDrag = PerfBudget(row: "QB-S3", series: ["canvas-drag"], measure: .latency, limit: 3)
    /// QB-S4, SP5: selection handle drag (target p95 ≤ 2).
    static let handleDrag = PerfBudget(row: "QB-S4", series: ["handle-drag"], measure: .latency, limit: 3)
    /// QB-S5, SP8 (and SP3's ruler scrub, whose series its feature names): key drag (target p95 ≤ 2).
    static let timelineDrag = PerfBudget(row: "QB-S5", series: ["key-drag"], measure: .latency, limit: 3)
    /// QB-S6, SP7: curve handle and tone point drag (target p95 ≤ 2).
    static let curveDrag = PerfBudget(row: "QB-S6", series: ["curve-drag"], measure: .latency, limit: 3)
    /// QB-S7, SP4: layer list and thumbnail grid scroll, p95 interval in
    /// refreshes (target ≤ 1.5); 7.1 sets its gate from CI, so no placeholder.
    static let listScroll = PerfBudget(row: "QB-S7", series: ["layers-scroll", "grid-scroll"], measure: .intervals, limit: nil)
    /// QB-S8, SP9: chip, preset, tab, tool and transport press to the selected state drawn (target p95 ≤ 1).
    static let press = PerfBudget(row: "QB-S8", series: ["press"], measure: .latency, limit: 2)
    /// QB-S9, SJ15: a state fade's `fade-start` to `fade-end`, in seconds, ±1
    /// refresh; 0 under Reduce Motion. SJ15 reads this; `perf()` skips fades.
    static let fade = PerfBudget(row: "QB-S9", series: ["chip"], measure: .fade, limit: 0.14)
    /// QB-S10, SP10: timeline slot divider drag (target p95 ≤ 2).
    static let slotDrag = PerfBudget(row: "QB-S10", series: ["slot-drag"], measure: .latency, limit: 3)

    /// Every 7.1 row, QB-S1 to QB-S10 in order.
    static let perfBudgets: [PerfBudget] = [
        barSliderDrag, sliderKey, canvasDrag, handleDrag, timelineDrag, curveDrag, listScroll, press, fade, slotDrag,
    ]
}
