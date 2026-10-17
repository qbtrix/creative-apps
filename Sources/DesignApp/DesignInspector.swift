// DesignInspector.swift: Properties in Design's inspector, its rows in a
// container identified `design.properties` inside the scroll view. A selected
// layer shows its header (name, then kind unless the name says it, then size),
// then Align (DesignAlignBar), then Layer (Hidden and Locked checkboxes), Frame (X, Y, W and H as scrub
// fields) and Fill (the color well; a text layer's is its text color, a group
// has none), then for a text layer its Text section (DesignInspectorText). A
// locked layer, or one inside a locked group, can't be edited, so Frame and
// Fill are disabled and a line says why. With only a page selected it shows
// DesignInspectorPage. With several layers selected (D0-5c) it shows "<n> Layers",
// Align with Distribute, then Frame and Fill: a row whose value every selected
// layer shares edits it on all of them (`.setStyle`), and one whose values differ
// reads "Mixed" as plain text (a mixed scrub field is needs-ui #2148). Every
// control's help comes from the Model, and each carries its DesignControlID and
// lists itself in `suite.controls`. Values in, intents out; the model clamps and
// refuses what it must. Opacity, Corners and Stroke, the hint and the frame
// fields' live scrub are DesignInspectorStyle.
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
                    DesignSeveralProperties(model: model, perform: perform)
                } else if let node = model.selectedNode {
                    DesignNodeProperties(
                        model: model, node: node, lockHelp: model.lockHelp(node.id), alignHelp: model.alignHelps,
                        perform: perform
                    ).id(node.id)
                } else if let page = model.selectedPage {
                    DesignPageProperties(page: page).id(page.id)
                }
            }
            // The id sits on a container inside the ScrollView, not on the ScrollView: SuiteWindow's
            // `.accessibilityElement(children: .contain)` modifies the inspector's existing element (this
            // scroll view) and its `suite.inspector` replaced an id there (#1443).
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("design.properties")
        }
    }
}

/// One of X, Y, W and H: its row label, its field's spoken name, its frame field and its range.
private struct FrameRow: Identifiable {
    let label: String
    let name: String
    let field: DesignFrameField
    let range: ClosedRange<Double>
    var id: DesignFrameField { field }

    /// How far X and Y can be set, and the most W and H can be, in points.
    private static let positionRange = -100_000.0...100_000.0
    private static let sizeRange = 1.0...100_000.0

    static let all = [
        FrameRow(label: "X", name: "X position", field: .x, range: positionRange),
        FrameRow(label: "Y", name: "Y position", field: .y, range: positionRange),
        FrameRow(label: "W", name: "Width", field: .width, range: sizeRange),
        FrameRow(label: "H", name: "Height", field: .height, range: sizeRange),
    ]

    /// This row's value in `frame`.
    func value(in frame: DesignRect) -> Double {
        switch field {
        case .x: frame.x
        case .y: frame.y
        case .width: frame.width
        case .height: frame.height
        }
    }

    /// This row's scrub field over the selection (DesignFrameScrub): a drag previews on the live box
    /// and lands as one step (#536). Disabled with `help` as its tooltip when it can't edit.
    @MainActor func scrubField(_ model: DesignWorkspace, help: String?, perform: @escaping DesignPerform) -> some View {
        DesignFrameScrub(
            model: model, name: name, field: field, range: range, read: { value(in: $0.frame) }, help: help,
            perform: perform)
    }
}

/// The selected layer's header and sections.
private struct DesignNodeProperties: View {
    let model: DesignWorkspace
    let node: DesignNode
    /// Why the layer can't be edited (it or a group around it is locked), or nil.
    let lockHelp: String?
    /// Why each Align command can't run, keyed by edge.
    let alignHelp: [DesignAlignEdge: String]
    let perform: DesignPerform
    /// The X field's leading x, where the hint starts.
    @State private var valueColumn: CGFloat = 0

    var body: some View {
        // Why the rows are off, named for the layer ("Unlock A to change it."), or nil.
        let hint = model.styleHelp(.opacity) == nil ? nil : model.styleHint(.opacity)
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader(node.name, details: node.inspectorDetails)
            DesignAlignBar(help: alignHelp, perform: perform)
            InspectorSection("Layer") {
                InspectorRow("") {
                    Toggle("Hidden", isOn: Binding(get: { node.isHidden }, set: { perform(.setHidden(node.id, $0)) }))
                        .toggleStyle(.checkbox)
                }
                InspectorRow("") {
                    Toggle("Locked", isOn: Binding(get: { node.isLocked }, set: { perform(.setLocked(node.id, $0)) }))
                        .toggleStyle(.checkbox)
                }
                DesignOpacityRow(model: model, perform: perform)
                if let hint { DesignStyleHint(text: hint, column: valueColumn) }
            }
            InspectorSection("Frame") {
                VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                    ForEach(FrameRow.all) { row in
                        InspectorRow(row.label) {
                            row.scrubField(model, help: lockHelp, perform: perform)
                                .onGeometryChange(for: CGFloat.self) {
                                    $0.frame(in: .named(DesignStyleHint.space)).minX
                                } action: { if row.field == .x { valueColumn = $0 } }
                        }
                    }
                }
            }
            DesignInspectorStyle(model: model, perform: perform)
            if let label = node.kind.fillLabel {
                InspectorSection("Fill") {
                    InspectorColorWellRow(label, color: HexColor(node.fill.red, node.fill.green, node.fill.blue)) {
                        perform(.setFill(node.id, DesignColor($0.red, $0.green, $0.blue)))
                    }
                    .accessibilityIdentifier("design.fill")
                    .disabled(lockHelp != nil)
                    .help(lockHelp ?? "")
                    .suiteControl(
                        id: DesignControlID.inspectorFill, enabled: lockHelp == nil, reason: lockHelp, identifies: false)
                }
            }
            if node.kind == .text { DesignInspectorText() }
        }
        .coordinateSpace(.named(DesignStyleHint.space))
    }
}

/// Several selected layers: "<n> Layers", Align with Distribute, then Frame and Fill over them all.
private struct DesignSeveralProperties: View {
    let model: DesignWorkspace
    let perform: DesignPerform

    var body: some View {
        let frameHelp = model.styleHelp(.frame)
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader(model.selectionCountText ?? "")
            DesignAlignBar(help: alignHelp, distributeHelp: distributeHelp, perform: perform)
            InspectorSection("Frame") {
                VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                    ForEach(FrameRow.all) { row in
                        InspectorRow(row.label) {
                            if model.sharedValue({ row.value(in: $0.frame) }) != nil {
                                row.scrubField(model, help: frameHelp, perform: perform)
                            } else {
                                mixed(frameHelp)
                            }
                        }
                    }
                }
            }
            // A group has no fill, so the row shows only when every selected layer has one.
            if model.selectedNodes.allSatisfy({ $0.kind.fillLabel != nil }) {
                let fillHelp = model.styleHelp(.fill)
                InspectorSection("Fill") {
                    if let fill = model.sharedValue(\.fill) {
                        InspectorColorWellRow("Fill", color: HexColor(fill.red, fill.green, fill.blue)) {
                            perform(.setStyle(.fill(DesignColor($0.red, $0.green, $0.blue))))
                        }
                        .accessibilityIdentifier("design.fill")
                        .disabled(fillHelp != nil)
                        .help(fillHelp ?? "")
                        .suiteControl(
                            id: DesignControlID.inspectorFill, enabled: fillHelp == nil, reason: fillHelp, identifies: false)
                    } else {
                        InspectorRow("Fill") { mixed(fillHelp) }
                    }
                }
            }
        }
    }

    private var alignHelp: [DesignAlignEdge: String] {
        Dictionary(uniqueKeysWithValues: DesignAlignEdge.allCases.compactMap { edge in
            model.help(.align(edge)).map { (edge, $0) }
        })
    }

    private var distributeHelp: [DesignDistributeAxis: String] {
        Dictionary(uniqueKeysWithValues: DesignDistributeAxis.allCases.compactMap { axis in
            model.help(.distribute(axis)).map { (axis, $0) }
        })
    }

    /// A row whose values differ: plain text, not a control, with the row's help as its tooltip.
    private func mixed(_ help: String?) -> some View {
        Text("Mixed")
            .font(SuiteFont.inspectorValue)
            .foregroundStyle(SuiteColor.secondaryText)
            .help(help ?? "")
    }
}
