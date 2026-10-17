// DesignAlignBar.swift: the Align section of Design's inspector: the six align
// commands for the selected layer as SuiteUI inspector actions in two columns,
// horizontal on the left (Left, Center, Right) and vertical on the right (Top,
// Middle, Bottom). With several layers selected two full-width rows add
// Distribute Horizontally and Vertically, and every button runs its DesignCommand. Each
// shows its symbol, its tooltip is its title, one that can't run is disabled
// with the reason from the Model (alignHelps, help(_:)), and each carries its
// DesignControlID and lists itself in `suite.controls`. Values in, intents out.
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

    /// Each grid row: a horizontal command, then its vertical partner.
    private static let rows: [[DesignAlignEdge]] = [[.left, .top], [.center, .middle], [.right, .bottom]]

    var body: some View {
        InspectorSection("Align") {
            Grid(horizontalSpacing: SuiteSpacing.xs, verticalSpacing: SuiteSpacing.xs) {
                ForEach(Self.rows, id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { action($0) }
                    }
                }
                if let distributeHelp {
                    // Full width each: "Distribute Horizontally" wraps in a half-width cell.
                    ForEach(DesignDistributeAxis.allCases, id: \.self) { axis in
                        GridRow { distribute(axis, distributeHelp[axis]).gridCellColumns(2) }
                    }
                }
            }
        }
    }

    private func action(_ edge: DesignAlignEdge) -> some View {
        InspectorAction(ToolbarAction(
            edge.title, systemImage: edge.systemImage, unavailableHelp: help[edge],
            identifier: DesignControlID.align(edge)
        ) {
            perform(distributeHelp == nil ? .align(edge) : .command(.align(edge)))
        })
    }

    private func distribute(_ axis: DesignDistributeAxis, _ help: String?) -> some View {
        InspectorAction(ToolbarAction(
            axis.title, systemImage: axis == .horizontal ? "distribute.horizontal.center" : "distribute.vertical.center",
            unavailableHelp: help, identifier: DesignControlID.distribute(axis)
        ) {
            perform(.command(.distribute(axis)))
        })
    }
}
