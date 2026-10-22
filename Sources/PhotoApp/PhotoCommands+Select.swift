// PhotoCommands+Select.swift: Photo's Select menu: All (Command-A, see
// PhotoMenu.selectAll), Deselect, and All Layers (Option-Command-A), which
// picks every row in the Layers list (multi-layer-select PM-3) and is off
// with its reason when no image is open or a sheet is up. All Layers' spec is
// local until PM-5 registers `layer.select-all` in Photo's catalog.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

extension PhotoCommands {
    var selectMenu: some Commands {
        CommandMenu("Select") {
            // Off only for a focused window with no image: a sheet's window may
            // not carry the focused value, and its field still needs Command-A (PhotoMenuState).
            menu.selectAllItem
            menu.item("select.deselect", shortcut: KeyboardShortcut("d")) { menu.perform(.deselect) }
            Divider()
            menu.allLayersItem
        }
    }
}

extension PhotoMenu {
    /// All Layers' spec: on while a window's image has layers and no sheet is up.
    static let allLayersSpec = CommandSpec<PhotoMenuState>.typed(
        "layer.select-all", title: "All Layers", summary: "Picks every layer in the Layers list.",
        kind: .view, params: JSONValue.self, example: .object([:]),
        availability: { state in
            if !state.hasWindow || state.workspace.canvas == nil || state.workspace.layers.isEmpty {
                return .unavailable("Open an image first.")
            }
            return state.isPresenting ? .unavailable("Finish the open sheet first.") : .available
        }
    ) { _, _ in JSONValue.object([:]) }

    /// Select > All: the canvas's pixels, Command-A.
    @MainActor var selectAllItem: MenuCommand {
        item("select.all", shortcut: KeyboardShortcut("a")) { selectAll() }
    }

    /// Select > All Layers, Option-Command-A: every layer picked in the Layers list.
    @MainActor var allLayersItem: MenuCommand {
        MenuCommand(
            Self.allLayersSpec, on: state(), systemImage: "square.3.layers.3d",
            shortcut: KeyboardShortcut("a", modifiers: [.command, .option])
        ) { perform(.selectAllLayers) }
    }
}
