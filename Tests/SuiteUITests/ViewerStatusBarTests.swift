// ViewerStatusBarTests.swift: SuiteUI's ViewerStatusBar takes an app's refusal
// at its leading edge in caption text (a sentence, not the pill type) and a
// "Preview data" pill last; each widens the bar it is drawn in. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct ViewerStatusBarTests {
    @Test func theRefusalIsCaptionTextNotAPill() {
        #expect(ViewerStatusBar<EmptyView>.messageFont == SuiteFont.caption)
        #expect(ViewerStatusBar<EmptyView>.messageFont != SuiteFont.pill)
    }

    @Test func aMessageAndThePreviewPillEachWidenTheBar() {
        func width(_ bar: some View) -> CGFloat { NSHostingView(rootView: bar.fixedSize()).fittingSize.width }
        let plain = width(ViewerStatusBar(zoom: 1, size: "800 × 600 px"))
        let preview = width(ViewerStatusBar(zoom: 1, size: "800 × 600 px", preview: ("Sample data.", "x.preview")))
        let message = width(ViewerStatusBar(zoom: 1, size: "800 × 600 px", message: ("Pick a pixel layer.", "x.message")))
        #expect(preview > plain + 40, "the Preview data pill should draw")
        #expect(message > plain + 40, "the refusal should draw")
    }
}
