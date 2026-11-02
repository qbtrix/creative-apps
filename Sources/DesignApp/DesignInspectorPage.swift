// DesignInspectorPage.swift: Design's inspector with only a page selected: the
// page's name and size in the header, then a Page Size section (not "Frame",
// which names a layer kind, #2354) with its Width and Height as ScrubFields
// (canvas-basics CB-9, `design.inspector.page-width` and `-height`), and a hint
// pointing at the layers. A drag shows its value in the row alone and sends
// `.setPageSize` once at its end; a typed value or a key press sends it once,
// so each change is one "Change Page Size" step. Layers past a smaller page
// stay, dimmed on the canvas (DesignPastEdge), and the Model's pastEdgeNote
// under the rows says so.
import DesignModel
import SuiteUI
import SwiftUI

/// A page with no layer selected: its name, size and a pointer to the layers.
struct DesignPageProperties: View {
    let page: DesignPage
    let perform: DesignPerform

    var body: some View {
        let width = page.frameWidth
        let height = page.frameHeight
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader(page.name, details: page.inspectorDetails)
            InspectorSection("Page Size") {
                InspectorRow("W") {
                    DesignPageSide(name: "Width", value: width, id: DesignControlID.inspectorPageWidth) {
                        perform(.setPageSize(width: $0, height: height))
                    }
                }
                InspectorRow("H") {
                    DesignPageSide(name: "Height", value: height, id: DesignControlID.inspectorPageHeight) {
                        perform(.setPageSize(width: width, height: $0))
                    }
                }
                if let note = page.pastEdgeNote { InspectorNote(note) }
                InspectorNote("Select a layer to edit its properties.")
            }
        }
    }
}

/// One side of the page, 1 to 100,000 pt. The value under way is the row's own until it ends;
/// it moves to ScrubField's commit-on-end mode once SuiteUI has one (#3223).
private struct DesignPageSide: View {
    let name: String
    let value: Double
    let id: String
    let commit: @MainActor (Double) -> Void
    @State private var pending: Double?

    var body: some View {
        ScrubField(name, value: pending ?? value, in: 1...100_000, step: 1, unit: "pt", decimals: 0) {
            pending = $0
        } onEnd: {
            if let pending { commit(pending) }
            pending = nil
        }
        .suiteControl(id: id, enabled: true, reason: nil)
    }
}
