// TimelineToolbarTests.swift: the strip's zoom controls (timeline packet,
// TL-17). The toolbar's Zoom bar runs from fit (1) to TimelineZoom's clamp
// for the host's frameWidth and Fit sets 1; Command-plus from fit goes to the
// next ViewerZoom stop, Command-minus back, Command-0 to fit; the toolbar's
// controls register in suite.controls with reasons equal to their help, each
// at least 20 pt (the Fit chip 28). No view is hosted. macOS only (SuiteUI).
@testable import SuiteUI
import Testing

@Suite struct TimelineToolbarTests {
    @Test func theZoomBarRunsFromFitToTheClampsMax() {
        #expect(TimelineToolbarControls(frameWidth: 4).barRange == 1...16)
        #expect(TimelineToolbarControls(frameWidth: 10).barRange == TimelineZoom.range(frameWidth: 10))
        #expect(TimelineToolbarControls(frameWidth: 10).barRange.upperBound == 6.4)
        // A host already 64 pt per frame wide can't zoom: the bar is disabled and says why.
        let wide = TimelineToolbarControls(frameWidth: 80)
        #expect(wide.barRange == 1...1)
        #expect(!wide.zoomEntry.enabled)
        #expect(TimelineToolbarControls(frameWidth: 4).zoomEntry.enabled)
    }

    @Test func fitSetsOne() {
        #expect(TimelineToolbarControls.fitZoom == 1)
        #expect(TimelineZoomKey.fit.zoom(from: 6, frameWidth: 4) == TimelineToolbarControls.fitZoom)
    }

    @Test func commandPlusFromFitGoesToTheNextStop() {
        let plus = TimelineZoomKey("=")
        #expect(plus == .zoomIn)
        #expect(TimelineZoomKey("+") == .zoomIn)
        #expect(plus?.zoom(from: 1, frameWidth: 4) == 1.5)
        #expect(plus?.zoom(from: 1, frameWidth: 4) == TimelineZoom.zoomedIn(from: 1, frameWidth: 4))
        #expect(TimelineZoomKey("-")?.zoom(from: 1.5, frameWidth: 4) == 1)
        #expect(TimelineZoomKey("-")?.zoom(from: 1, frameWidth: 4) == 1)
        #expect(TimelineZoomKey("0")?.zoom(from: 16, frameWidth: 4) == 1)
        #expect(TimelineZoomKey("a") == nil)
    }

    @Test func theControlsRegisterWithReasonsEqualToTheirHelpEachAtLeast20Points() {
        let controls = TimelineToolbarControls(frameWidth: 4)
        let entries = [controls.zoomEntry, controls.fitEntry]
        #expect(entries.map(\.id) == ["suite.timeline.zoom", "suite.timeline.fit"])
        #expect(entries.map(\.reason) == [TimelineToolbarControls.zoomHelp, TimelineToolbarControls.fitHelp])
        #expect(entries.allSatisfy { !($0.reason ?? "").isEmpty })
        #expect(TimelineToolbarControls.zoomHeight >= 20)
        #expect(TimelineToolbarControls.fitHeight >= 20)
        #expect(TimelineToolbarControls.fitHeight == 28)
        // The row fits the 36 pt the strip's ideal height already holds for it.
        #expect(TimelineToolbarControls.zoomHeight <= SuiteSize.timelineSlotToolbar)
        #expect(TimelineToolbarControls.fitHeight <= SuiteSize.timelineSlotToolbar)
    }
}
