// GalleryDialogs.swift: the gallery's dialog pages. `sheet` draws SuiteSheet
// as a page (not presented): the standard settings sheet with a note and a
// confirm, and the wide New sheet with a problem that disables its confirm.
// `alert` has one button that raises a problem alert (suiteProblemAlert).
import SwiftUI

enum GalleryDialogs {
    @MainActor static let pages: GalleryPages = [
        "sheet": { AnyView(GallerySheetPage()) }, "alert": { AnyView(GalleryAlertPage()) },
    ]
}

private struct GallerySheetPage: View {
    @State private var width = "1920"

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.l) {
            SuiteSheet(
                "Image Size", note: "Now 1920 × 1080 px.", cancelIdentifier: "suite.gallery.sheet.cancel",
                confirm: .init("Resize", identifier: "suite.gallery.sheet.confirm", help: "Resize") {}, onCancel: {}
            ) {
                Form { TextField("Width", text: $width).accessibilityIdentifier("suite.gallery.sheet.width") }
            }
            SuiteSheet(
                "New Animation", width: .wide, problem: "Width must be 1 to 8192.",
                cancelIdentifier: "suite.gallery.sheet.wide.cancel",
                confirm: .init(
                    "Create", identifier: "suite.gallery.sheet.wide.create", help: "Width must be 1 to 8192.",
                    isEnabled: false) {},
                onCancel: {}
            ) {
                Form { TextField("Width", text: $width).accessibilityIdentifier("suite.gallery.sheet.wide.width") }
            }
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct GalleryAlertPage: View {
    @State private var problem: String?

    var body: some View {
        Button("Show Problem") { problem = "The file couldn’t be opened." }
            .help("Show a problem alert")
            .suiteControl(id: "suite.gallery.alert.show", enabled: true, reason: nil)
            .suiteProblemAlert($problem)
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
