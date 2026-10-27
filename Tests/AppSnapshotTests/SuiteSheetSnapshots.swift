// SuiteSheetSnapshots.swift (#3964): SuiteUI's SuiteSheet with a field, a
// message line and Cancel / Resize, Resize on and off with its reason, each
// Light and Dark: suite-sheet-light, suite-sheet-dark, suite-sheet-disabled-light
// and suite-sheet-disabled-dark. macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteSheetSnapshots {
    @Test func sheet() throws {
        for (scheme, suffix) in [(ColorScheme.light, "light"), (.dark, "dark")] {
            try snapshot(SheetStage(reason: nil), name: "suite-sheet-\(suffix)", scheme: scheme)
            try snapshot(SheetStage(reason: "Type each side as a whole number of pixels."),
                         name: "suite-sheet-disabled-\(suffix)", scheme: scheme)
        }
    }
}

/// One sheet on a panel at the top left of the 1440x900 frame.
private struct SheetStage: View {
    let reason: String?

    var body: some View {
        SuiteSheet(
            "Image Size", message: "Now 640 × 480 px.", cancelID: "suite.sheet.cancel", onCancel: {},
            action: MenuCommand("Resize", help: "Resample every layer.") {}, actionID: "suite.sheet.resize", reason: reason
        ) {
            Form { TextField("Width", text: .constant("640")) }
        }
        .background(SuiteColor.panel)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
