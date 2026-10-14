// DesignObjectMenu.swift: Design's Object menu. Align holds the six align
// commands for the selected layer (Align Left, Center, Right, Top, Middle and
// Bottom), each sent as DesignIntent.align. A command that can't run (no
// layer, a locked layer or group, a hidden group, already there) is disabled
// and its tooltip says why, from DesignMenu.alignHelp.
import DesignModel
import SwiftUI

/// Object: the Align submenu.
struct DesignObjectMenu: View {
    let menu: DesignMenu

    var body: some View {
        Menu("Align") {
            ForEach(DesignAlignEdge.allCases, id: \.self) { edge in
                if edge == .top { Divider() }
                Button(edge.title, systemImage: edge.systemImage) { menu.perform(.align(edge)) }
                    .disabled(menu.alignHelp[edge] != nil)
                    .help(menu.alignHelp[edge] ?? edge.title)
            }
        }
    }
}
