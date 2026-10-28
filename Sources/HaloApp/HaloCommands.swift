// HaloCommands.swift: what every Halo menu shares, and the Layer menu. The
// focused window publishes its HaloProject (`haloProject`, read only) next to
// `haloPerform`; a menu item is SuiteUI's MenuCommand on its catalog spec over
// HaloMenuState (AC-h3): titled by the Model, disabled, never hidden, with the
// spec's reason as help, and it sends its HaloCommand through `haloPerform`.
// The plain keys (Space, arrows, Home, End, I, O, Delete) act only while the
// viewer or timeline has focus, so items don't take them as key equivalents:
// typing in a field never plays, moves or deletes. Layer: New ▸ (Solid,
// Shape, Text, Null), Duplicate, Rename…, Delete, Bring Forward, Send Backward.
import HaloModel
import SuiteUI
import SwiftUI

extension FocusedValues {
    /// The focused Halo window's project, for menu titles and availability; nil with no Halo window.
    @Entry var haloProject: HaloProject?
}

/// The focused window as the menus see it: its project and where to send a command.
struct HaloMenuTarget {
    let model: HaloProject?
    let perform: (@MainActor (HaloCommand) -> Void)?

    /// What the items read: the project, nil with nowhere to send a command.
    var state: HaloMenuState { HaloMenuState(project: perform == nil ? nil : model) }

    /// Nil when `command` can act now; else why not.
    func help(for command: HaloCommand) -> String? { state.availability(command.commandID).why }

    func title(for command: HaloCommand) -> String { state.title(command) }

    /// The menu item for `command`, built from its catalog spec; `title` overrides the Model's.
    func item(
        _ command: HaloCommand, title: String? = nil, systemImage: String? = nil, shortcut: KeyboardShortcut? = nil
    ) -> MenuCommand {
        MenuCommand(HaloMenuState.spec(command.commandID), on: state, title: title ?? self.title(for: command),
                    systemImage: systemImage, shortcut: shortcut) { perform?(command) }
    }
}

/// Layer: New ▸ (Solid, Shape, Text, Null), Duplicate ⇧⌘D, Rename…, Delete
/// (⌫ in the viewer or timeline), Bring Forward ⌘], Send Backward ⌘[; then Layer Style…,
/// Copy, Paste and Clear Layer Style (HaloStyleMenuItems, HaloWindow+Styling.swift).
struct HaloCommands: Commands {
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform
    @FocusedValue(\.haloRunStyleMenu) private var runStyleMenu

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandMenu("Layer") {
            Menu("New") {
                ForEach(HaloLayerKind.allCases, id: \.self) { kind in
                    target.item(.newLayer(kind), systemImage: kind.systemImage)
                }
            }
            target.item(
                .duplicateLayer, systemImage: "plus.square.on.square",
                shortcut: KeyboardShortcut("d", modifiers: [.command, .shift]))
            target.item(.beginRenameLayer)
            target.item(.deleteLayer, systemImage: "trash")
            Divider()
            target.item(.bringLayerForward, shortcut: KeyboardShortcut("]"))
            target.item(.sendLayerBackward, shortcut: KeyboardShortcut("["))
            Divider()
            HaloStyleMenuItems(model: model, run: runStyleMenu)
        }
    }
}

extension HaloLayerKind {
    /// The SF Symbol for the kind in lists and menus.
    var systemImage: String {
        switch self {
        case .solid: "square.fill"
        case .shape: "star"
        case .text: "textformat"
        case .null: "square.dashed"
        }
    }
}
