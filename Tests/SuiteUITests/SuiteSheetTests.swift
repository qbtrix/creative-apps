// SuiteSheetTests.swift: SuiteSheet, the frame every app sheet is drawn in:
// its two widths are the inspector's widest and the content's minimum, a
// note or a problem makes it taller, and the confirm keeps what it is given.
// macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct SuiteSheetTests {
    private func size(_ sheet: some View) -> CGSize { NSHostingView(rootView: sheet).fittingSize }

    @Test func theTwoWidthsAreTheInspectorsWidestAndTheContentMinimum() {
        let standard = size(SuiteSheet("Export", cancelIdentifier: "c", onCancel: {}) { Text("Body") })
        let wide = size(SuiteSheet("New", width: .wide, cancelIdentifier: "c", onCancel: {}) { Text("Body") })
        #expect(standard.width == SuiteSize.inspectorWidth.max)
        #expect(wide.width == SuiteSize.contentMinimum.width)
    }

    @Test func aNoteAndAProblemEachAddARow() {
        let plain = size(SuiteSheet("Export", cancelIdentifier: "c", onCancel: {}) { Text("Body") })
        let noted = size(SuiteSheet("Export", note: "PNG keeps transparent pixels.", cancelIdentifier: "c", onCancel: {}) { Text("Body") })
        let refused = size(SuiteSheet("Export", problem: "Width must be 1 to 8192.", cancelIdentifier: "c", onCancel: {}) { Text("Body") })
        #expect(noted.height > plain.height && refused.height > plain.height)
    }

    @Test func theConfirmKeepsWhatItIsGiven() {
        var ran = false
        let confirm = SuiteSheet<EmptyView>.Confirm("Resize", identifier: "photo.size.resize", help: "Type each side.", isEnabled: false) { ran = true }
        #expect(confirm.title == "Resize" && confirm.identifier == "photo.size.resize")
        #expect(confirm.help == "Type each side." && !confirm.isEnabled)
        confirm.perform()
        #expect(ran)
    }
}
