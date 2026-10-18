// DesignObjectMenu.swift: Design's Object menu. Group (⌘G) and Ungroup
// (⇧⌘G); the Arrange submenu (Bring to Front ⇧⌘], Bring Forward ⌘], Send
// Backward ⌘[, Send to Back ⇧⌘[); the Align submenu with the six align
// commands for the selection, each sent as DesignIntent.align; then Distribute
// Horizontally and Vertically at the top level. A command that can't run (no
// layer, a locked layer or group, a hidden group, already there, not built
// yet) is disabled and its tooltip says why, from DesignMenu's Model help. A
// submenu whose every item is off is off too, with its first item's reason.
// Every item, submenus included, carries its SF Symbol.
import DesignModel
import SuiteUI
import SwiftUI

/// Object: Group, Ungroup, Arrange, Align and Distribute.
struct DesignObjectMenu: View {
    let menu: DesignMenu

    var body: some View {
        MenuCommand(
            menu: menu, title: "Group", systemImage: "rectangle.3.group", command: .group,
            shortcut: KeyboardShortcut("g"))
        MenuCommand(
            menu: menu, title: "Ungroup", systemImage: "rectangle.dashed", command: .ungroup,
            shortcut: KeyboardShortcut("g", modifiers: [.shift, .command])
        )
        Divider()
        let arrangeHelp = DesignArrangeStep.allCases.map { menu.help(.arrange($0)) }
        let arrangeOff = arrangeHelp.allSatisfy { $0 != nil }
        Menu("Arrange", systemImage: "square.3.layers.3d") {
            ForEach(DesignArrangeStep.allCases, id: \.self) { step in
                MenuCommand(
                    menu: menu, title: step.title, systemImage: step.systemImage, command: .arrange(step),
                    shortcut: step.shortcut)
            }
        }
        .disabled(arrangeOff)
        .help(arrangeOff ? arrangeHelp.compactMap { $0 }.first ?? "" : "")
        let alignOff = DesignAlignEdge.allCases.allSatisfy { menu.alignHelp[$0] != nil }
        Menu("Align", systemImage: "align.horizontal.center") {
            ForEach(DesignAlignEdge.allCases, id: \.self) { edge in
                if edge == .top { Divider() }
                Button(edge.title, systemImage: edge.systemImage) { menu.perform(.align(edge)) }
                    .disabled(menu.alignHelp[edge] != nil)
                    .help(menu.alignHelp[edge] ?? edge.title)
            }
        }
        .disabled(alignOff)
        .help(alignOff ? DesignAlignEdge.allCases.compactMap { menu.alignHelp[$0] }.first ?? "" : "")
        ForEach(DesignDistributeAxis.allCases, id: \.self) { axis in
            MenuCommand(menu: menu, title: axis.title, systemImage: axis.systemImage, command: .distribute(axis))
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

    /// The layer stack with the moved layer's place filled.
    var systemImage: String {
        switch self {
        case .bringToFront: "square.3.layers.3d.top.filled"
        case .bringForward: "square.2.layers.3d.top.filled"
        case .sendBackward: "square.2.layers.3d.bottom.filled"
        case .sendToBack: "square.3.layers.3d.bottom.filled"
        }
    }
}

extension DesignDistributeAxis {
    /// The same symbols the inspector's Align row draws.
    var systemImage: String { self == .horizontal ? "distribute.horizontal.center" : "distribute.vertical.center" }
}
