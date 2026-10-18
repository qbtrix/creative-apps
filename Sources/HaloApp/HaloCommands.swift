// HaloCommands.swift: what every Halo menu shares, and the Layer menu. The
// focused window publishes its HaloProject (`haloProject`, read only) next to
// `haloPerform`; a menu item reads the project for its title and for
// `unavailableHelp(for:)`, and sends its HaloCommand through `haloPerform`.
// An item that can't act is disabled, never hidden, with the Model's reason
// as help. The plain keys (Space, arrows, Home, End, I, O, Delete) act only
// while the viewer or timeline has focus, so items name them in their help
// instead of taking them as key equivalents: typing in a field never plays,
// moves or deletes. Layer: New ▸ (Solid, Shape, Text, Null), Duplicate,
// Rename…, Delete, Bring Forward, Send Backward.
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

    /// Nil when `command` can act now; else why not.
    func help(for command: HaloCommand) -> String? {
        guard let model, perform != nil else { return "Open a Halo window first." }
        return model.unavailableHelp(for: command)
    }

    func title(for command: HaloCommand) -> String { model?.title(for: command) ?? command.title }
}

extension MenuCommand {
    /// One menu item for one command: titled by the Model, disabled with its
    /// reason as help. `key` names the focus-scoped plain key that also does it.
    init(
        command: HaloCommand, target: HaloMenuTarget, title: String? = nil, systemImage: String? = nil,
        shortcut: KeyboardShortcut? = nil, key: String? = nil
    ) {
        let reason = target.help(for: command)
        let text = title ?? target.title(for: command)
        self.init(
            text, systemImage: systemImage, shortcut: shortcut,
            help: reason ?? key.map { "Press \($0) while the viewer or timeline has focus." } ?? text,
            isEnabled: reason == nil) { target.perform?(command) }
    }
}

/// Layer: New ▸ (Solid, Shape, Text, Null), Duplicate ⇧⌘D, Rename…, Delete
/// (⌫ in the viewer or timeline), Bring Forward ⌘], Send Backward ⌘[.
struct HaloCommands: Commands {
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandMenu("Layer") {
            Menu("New") {
                ForEach(HaloLayerKind.allCases, id: \.self) { kind in
                    MenuCommand(command: .newLayer(kind), target: target, systemImage: kind.systemImage)
                }
            }
            MenuCommand(
                command: .duplicateLayer, target: target, systemImage: "plus.square.on.square",
                shortcut: KeyboardShortcut("d", modifiers: [.command, .shift]))
            MenuCommand(command: .beginRenameLayer, target: target)
            MenuCommand(command: .deleteLayer, target: target, systemImage: "trash", key: "Delete")
            Divider()
            MenuCommand(command: .bringLayerForward, target: target, shortcut: KeyboardShortcut("]"))
            MenuCommand(command: .sendLayerBackward, target: target, shortcut: KeyboardShortcut("["))
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
