// DesignInspector.swift: the Properties tab of Design's panel. A selected
// layer shows its header (name, then kind unless the name says it, then size),
// then Layer (Hidden and Locked checkboxes), Frame (X, Y, W and H as scrub
// fields) and Fill (the color well; a text layer's is its text color, a group
// has none). A locked layer, or one inside a locked group, can't be edited, so
// Frame and Fill are disabled and a line says why. With several layers selected
// Frame and Fill read "Multiple layers selected", disabled with the reason (#413).
// With only a page selected it shows the page's size, read only. Values in, intents out; the model clamps and refuses what it must.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignInspector: View {
    let model: DesignWorkspace
    let perform: DesignPerform

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if model.hasMultipleSelection {
                    DesignMultipleProperties(count: model.selectedNodeIDs.count)
                } else if let node = model.selectedNode {
                    DesignNodeProperties(node: node, lockHelp: model.lockHelp(node.id), perform: perform).id(node.id)
                } else if let page = model.selectedPage {
                    DesignPageProperties(page: page).id(page.id)
                }
            }
        }
        .accessibilityIdentifier("design.properties")
    }
}

/// The selected layer's header and sections.
private struct DesignNodeProperties: View {
    let node: DesignNode
    /// Why the layer can't be edited (it or a group around it is locked), or nil.
    let lockHelp: String?
    let perform: DesignPerform

    /// How far X and Y can be set, and the most W and H can be, in points.
    private static let positionRange = -100_000.0...100_000.0
    private static let sizeRange = 1.0...100_000.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader(node.name, details: node.inspectorDetails)
            InspectorSection("Layer") {
                InspectorRow("") {
                    Toggle("Hidden", isOn: Binding(get: { node.isHidden }, set: { perform(.setHidden(node.id, $0)) }))
                        .toggleStyle(.checkbox)
                }
                InspectorRow("") {
                    Toggle("Locked", isOn: Binding(get: { node.isLocked }, set: { perform(.setLocked(node.id, $0)) }))
                        .toggleStyle(.checkbox)
                }
                if let lockHelp { DesignPanelHint(lockHelp) }
            }
            InspectorSection("Frame") {
                VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                    frameRow("X", "X position", \.x, Self.positionRange)
                    frameRow("Y", "Y position", \.y, Self.positionRange)
                    frameRow("W", "Width", \.width, Self.sizeRange)
                    frameRow("H", "Height", \.height, Self.sizeRange)
                }
                .disabled(lockHelp != nil)
                .help(lockHelp ?? "")
            }
            if let label = node.kind.fillLabel {
                InspectorSection("Fill") {
                    InspectorColorWellRow(label, color: HexColor(node.fill.red, node.fill.green, node.fill.blue)) {
                        perform(.setFill(node.id, DesignColor($0.red, $0.green, $0.blue)))
                    }
                    .disabled(lockHelp != nil)
                    .help(lockHelp ?? "")
                }
            }
        }
    }

    /// One of X, Y, W and H: a scrub field that sends the whole frame with `field` changed.
    private func frameRow(
        _ label: String, _ name: String, _ field: WritableKeyPath<DesignRect, Double>, _ range: ClosedRange<Double>
    ) -> some View {
        InspectorRow(label) {
            ScrubField(name, value: node.frame[keyPath: field], in: range, step: 1, unit: "pt", decimals: 1) { value in
                var frame = node.frame
                frame[keyPath: field] = value
                perform(.setFrame(node.id, x: frame.x, y: frame.y, width: frame.width, height: frame.height))
            }
        }
    }
}

/// Several layers: a header with their count, and Frame and Fill that say so and can't be edited yet.
private struct DesignMultipleProperties: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader("\(count) Layers")
            ForEach(["Frame", "Fill"], id: \.self) { section in
                InspectorSection(section) {
                    InspectorRow("") {
                        Text(DesignWorkspace.multipleLayersText)
                            .font(SuiteFont.inspectorValue)
                            .foregroundStyle(SuiteColor.secondaryText)
                    }
                    .disabled(true)
                    DesignPanelHint(DesignWorkspace.multipleLayersHelp)
                }
            }
        }
    }
}

/// A page with no layer selected: its name, size and a pointer to the layers.
private struct DesignPageProperties: View {
    let page: DesignPage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader(page.name, details: page.inspectorDetails)
            InspectorSection("Frame") {
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
