// DesignInspectorPage.swift: Design's inspector with only a page selected: the
// page's name and size in the header, then a Page Size section with its W and
// H, read only (not "Frame", which names a layer kind, #2354), and a hint
// pointing at the layers. Moved unchanged out of DesignInspector (D0-5c), so
// the page-size rows (canvas-basics CB-9) land in a file of their own.
import DesignModel
import SuiteUI
import SwiftUI

/// A page with no layer selected: its name, size and a pointer to the layers.
struct DesignPageProperties: View {
    let page: DesignPage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader(page.name, details: page.inspectorDetails)
            InspectorSection("Page Size") {
                InspectorRow("W") { size(page.frameWidth) }
                InspectorRow("H") { size(page.frameHeight) }
                DesignPanelHint("Select a layer to edit its properties.")
            }
        }
    }

    private func size(_ points: Double) -> some View {
        Text("\(NumericInput.format(points, decimals: 0)) pt")
            .font(SuiteFont.inspectorValue)
            .foregroundStyle(SuiteColor.secondaryText)
    }
}
