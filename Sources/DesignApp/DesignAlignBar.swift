// DesignAlignBar.swift: the Align section of Design's inspector: the six align
// commands for the selected layer as SuiteUI inspector actions in two columns,
// horizontal on the left (Left, Center, Right) and vertical on the right (Top,
// Middle, Bottom). Each shows its symbol, its tooltip is its title, and one
// that can't run is disabled with the reason from DesignWorkspace.alignHelp.
// Values in, intents out.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignAlignBar: View {
    /// Why each command can't run, keyed by edge; an edge left out can run.
    let help: [DesignAlignEdge: String]
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
            }
        }
    }

    private func action(_ edge: DesignAlignEdge) -> some View {
        InspectorAction(ToolbarAction(edge.title, systemImage: edge.systemImage, unavailableHelp: help[edge]) {
            perform(.align(edge))
        })
    }
}
