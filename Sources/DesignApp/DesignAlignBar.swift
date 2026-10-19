// DesignAlignBar.swift: the Align section of Design's inspector: the six align
// commands for the selected layer as icon-only SuiteUI inspector actions in two
// rows, horizontal (Left, Center, Right) then vertical (Top, Middle, Bottom).
// With several layers selected a third row adds Distribute Horizontally and
// Vertically, and every button runs its DesignCommand. Each shows its symbol
// and its title as the tooltip; one that can't run is disabled and its tooltip
// names it and gives the reason from the Model (alignHelps, help(_:)). Each
// carries its DesignControlID and lists itself in `suite.controls`. A disabled
// Distribute button also shows its reason as a secondary caption under the row
// (`design.distribute.reason`), so it reads without hovering (#2438). Values in,
// intents out.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignAlignBar: View {
    /// Why each align command can't run, keyed by edge; an edge left out can run.
    let help: [DesignAlignEdge: String]
    /// Several layers: why each Distribute command can't run, keyed by axis. Nil with one
    /// layer, which shows no Distribute row and keeps today's one-layer align intent.
    var distributeHelp: [DesignDistributeAxis: String]? = nil
    let perform: DesignPerform

    /// The horizontal commands, then the vertical ones: one row each.
    private static let rows: [[DesignAlignEdge]] = [[.left, .center, .right], [.top, .middle, .bottom]]

    var body: some View {
        InspectorSection("Align") {
            ForEach(Self.rows, id: \.self) { row in
                HStack(spacing: SuiteSpacing.xs) {
                    ForEach(row, id: \.self) { action($0) }
                }
            }
            if let distributeHelp {
                HStack(spacing: SuiteSpacing.xs) {
                    ForEach(DesignDistributeAxis.allCases, id: \.self) { distribute($0, distributeHelp[$0]) }
                }
                if let caption = Self.distributeCaption(distributeHelp) {
                    Text(caption)
                        .font(SuiteFont.caption)
                        .foregroundStyle(SuiteColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("design.distribute.reason")
                }
            }
        }
    }

    /// The Model's reasons the Distribute rows can't run, each once, in axis order; nil when both can.
    static func distributeCaption(_ help: [DesignDistributeAxis: String]?) -> String? {
        var reasons: [String] = []
        for axis in DesignDistributeAxis.allCases {
            if let reason = help?[axis], !reasons.contains(reason) { reasons.append(reason) }
        }
        return reasons.isEmpty ? nil : reasons.joined(separator: "\n")
    }

    private func action(_ edge: DesignAlignEdge) -> some View {
        InspectorAction(
            ToolbarAction(
                edge.title, systemImage: edge.systemImage, unavailableHelp: help[edge],
                identifier: DesignControlID.align(edge)
            ) {
                perform(distributeHelp == nil ? .align(edge) : .command(.align(edge)))
            }, iconOnly: true)
    }

    private func distribute(_ axis: DesignDistributeAxis, _ help: String?) -> some View {
        InspectorAction(
            ToolbarAction(
                axis.title, systemImage: axis == .horizontal ? "distribute.horizontal.center" : "distribute.vertical.center",
                unavailableHelp: help, identifier: DesignControlID.distribute(axis)
            ) {
                perform(.command(.distribute(axis)))
            }, iconOnly: true)
    }
}
