// GalleryAppMarks.swift: the gallery's `app-marks` page, every AppMark on one
// sheet: per mark (the suite's, then the five apps'), the .icon at each size the
// Dock and Finder use (16 and 32 draw the small-size art), the .glyph, the .line
// at the switcher's size and the .line in a sidebar-style Label. Nothing on it
// is a control.
import SuiteModel
import SwiftUI

enum GalleryAppMarks {
    static let name = "app-marks"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryAppMarksPage()) }]

    /// The .icon sizes shown, in points.
    static let iconSides: [CGFloat] = [16, 32, 64, 128]
}

private struct GalleryAppMarksPage: View {
    private let marks: [SuiteApp] = SuiteApp.allCases

    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: SuiteSpacing.l, verticalSpacing: SuiteSpacing.m) {
                ForEach(marks, id: \.self) { app in
                    GridRow(alignment: .center) {
                        Text(app.displayName).font(SuiteFont.headline)
                        ForEach(GalleryAppMarks.iconSides, id: \.self) { side in
                            AppMark(app: app, style: .icon).frame(width: side, height: side)
                        }
                        AppMark(app: app, style: .glyph).frame(width: SuiteSize.toolButton, height: SuiteSize.toolButton)
                        AppMark(app: app, style: .line).frame(width: SuiteSize.switcherIcon, height: SuiteSize.switcherIcon)
                        Label { Text(app.displayName) } icon: { AppMark(app: app, style: .line).symbolSized() }
                    }
                }
            }
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
