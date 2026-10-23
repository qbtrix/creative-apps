// DesignObjectMenu.swift: Design's Object menu. Group (⌘G) and Ungroup
// (⇧⌘G); the Arrange submenu (Bring to Front ⇧⌘], Bring Forward ⌘], Send
// Backward ⌘[, Send to Back ⇧⌘[); the Align submenu with the six align
// commands for the selection, each sent as DesignIntent.align; then Distribute
// Horizontally and Vertically at the top level; then Flip Horizontal, Flip
// Vertical, Rotate 90° Left and Right, each a kernel TransformIntent (transform
// DT-2; off with `turnHelp` until the catalog has transform.*); then the Opacity submenu, 10% to 100% on every
// selected layer through `layer.set-opacity`'s availability, as the digit keys set it (brush-keys BK-10). A command that can't run (no
// layer, a locked layer or group, a hidden group, already there, not built
// yet) is disabled and its tooltip says why, from its catalog spec (AC-d3). A
// submenu whose every item is off is drawn as one off item instead, with its
// first item's reason: AppKit keeps a submenu's own item enabled (#2465).
// Every item, submenus included, carries its SF Symbol.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// Object: Group, Ungroup, Arrange, Align, Distribute, the transforms and Opacity.
struct DesignObjectMenu: View {
    let menu: DesignMenu

    var body: some View {
        menu.item("object.group", systemImage: "rectangle.3.group", shortcut: KeyboardShortcut("g")) { menu.perform(.command(.group)) }
        menu.item("object.ungroup", systemImage: "rectangle.dashed", shortcut: KeyboardShortcut("g", modifiers: [.shift, .command])) {
            menu.perform(.command(.ungroup))
        }
        Divider()
        // AppKit keeps a submenu's own item on whatever `.disabled` says, so an all-off one is a plain off item (#2465),
        // read from its first item's spec, which is off whenever the whole submenu is.
        if menu.arrangeMenuHelp != nil {
            menu.item(DesignMenuState.objectID(DesignArrangeStep.bringToFront.title), title: "Arrange", systemImage: "square.3.layers.3d") {}
        } else {
            Menu("Arrange", systemImage: "square.3.layers.3d") {
                ForEach(DesignArrangeStep.allCases, id: \.self) { step in
                    menu.item(DesignMenuState.objectID(step.title), systemImage: step.systemImage, shortcut: step.shortcut) {
                        menu.perform(.command(.arrange(step)))
                    }
                }
            }
        }
        if menu.alignMenuHelp != nil {
            menu.item(DesignMenuState.objectID(DesignAlignEdge.left.title), title: "Align", systemImage: "align.horizontal.center") {}
        } else {
            Menu("Align", systemImage: "align.horizontal.center") {
                ForEach(DesignAlignEdge.allCases, id: \.self) { edge in
                    if edge == .top { Divider() }
                    menu.item(DesignMenuState.objectID(edge.title), systemImage: edge.systemImage) { menu.perform(.align(edge)) }
                }
            }
        }
        ForEach(DesignDistributeAxis.allCases, id: \.self) { axis in
            menu.item(DesignMenuState.objectID(axis.title), systemImage: axis.systemImage) { menu.perform(.command(.distribute(axis))) }
        }
        Divider()
        ForEach(FlipDirection.allCases, id: \.self) { direction in
            menu.item("transform.flip", title: direction.title, systemImage: direction.systemImage) {
                menu.perform(.transform(.flip(direction)))
            }
        }
        menu.item("transform.rotate", title: "Rotate 90° Left", systemImage: "rotate.left") {
            menu.perform(.transform(.rotate(by: -90, drag: nil)))
        }
        menu.item("transform.rotate", title: "Rotate 90° Right", systemImage: "rotate.right") {
            menu.perform(.transform(.rotate(by: 90, drag: nil)))
        }
        Divider()
        if menu.workspace.layerOpacityHelp != nil {
            menu.item("layer.set-opacity", title: "Opacity", systemImage: "circle.lefthalf.filled") {}
        } else {
            Menu("Opacity", systemImage: "circle.lefthalf.filled") {
                ForEach(Self.percents, id: \.self) { percent in
                    menu.item("layer.set-opacity", title: "\(percent)%", systemImage: "circle.lefthalf.filled") {
                        menu.perform(.endEditRun)
                        menu.perform(.setStyle(.opacity(DesignWorkspace.keyOpacity(Double(percent)))))
                    }
                }
            }
        }
    }

    /// The Opacity submenu's percents, the ones the digit keys 1 to 9 and 0 set.
    static let percents = Array(stride(from: 10, through: 100, by: 10))
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
