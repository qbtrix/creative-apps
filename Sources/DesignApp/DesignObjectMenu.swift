// DesignObjectMenu.swift: Design's Object menu. Group (⌘G) and Ungroup
// (⇧⌘G); the Arrange submenu (Bring to Front ⇧⌘], Bring Forward ⌘], Send
// Backward ⌘[, Send to Back ⇧⌘[); the Align submenu with the six align
// commands for the selection, each sent as DesignIntent.align; then Distribute
// Horizontally and Vertically at the top level. A command that can't run (no
// layer, a locked layer or group, a hidden group, already there, not built
// yet) is disabled and its tooltip says why, from DesignMenu's Model help.
import DesignModel
import SwiftUI

/// Object: Group, Ungroup, Arrange, Align and Distribute.
struct DesignObjectMenu: View {
    let menu: DesignMenu

    var body: some View {
        DesignCommandItem(menu: menu, title: "Group", command: .group, shortcut: KeyboardShortcut("g"))
        DesignCommandItem(
            menu: menu, title: "Ungroup", command: .ungroup, shortcut: KeyboardShortcut("g", modifiers: [.shift, .command])
        )
        Divider()
        Menu("Arrange") {
            ForEach(DesignArrangeStep.allCases, id: \.self) { step in
                DesignCommandItem(menu: menu, title: step.title, command: .arrange(step), shortcut: step.shortcut)
            }
        }
        Menu("Align") {
            ForEach(DesignAlignEdge.allCases, id: \.self) { edge in
                if edge == .top { Divider() }
                Button(edge.title, systemImage: edge.systemImage) { menu.perform(.align(edge)) }
                    .disabled(menu.alignHelp[edge] != nil)
                    .help(menu.alignHelp[edge] ?? edge.title)
            }
        }
        ForEach(DesignDistributeAxis.allCases, id: \.self) { axis in
            DesignCommandItem(menu: menu, title: axis.title, command: .distribute(axis))
        }
    }
}

extension DesignArrangeStep {
    /// ⌘] and ⌘[ move one place; with Shift, to the front or back.
    var shortcut: KeyboardShortcut {
        switch self {
        case .bringToFront: KeyboardShortcut("]", modifiers: [.shift, .command])
        case .bringForward: KeyboardShortcut("]")
        case .sendBackward: KeyboardShortcut("[")
        case .sendToBack: KeyboardShortcut("[", modifiers: [.shift, .command])
        }
    }
}
