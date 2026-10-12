// HaloCompositionCommands.swift: Halo's Composition menu in the menu bar: New
// Composition… (opens the sheet), Duplicate and Delete for the focused
// window's selected composition. The window publishes its actions as a
// focused scene value; a nil action disables its item rather than hiding it.
import SwiftUI

extension FocusedValues {
    /// The focused window's composition actions; nil with no Halo window.
    @Entry var haloCompositionActions: HaloCompositionActions?
}

/// What the Composition menu calls. `duplicate` is nil with no composition
/// selected; `delete` is nil then too, and when only one composition is left.
struct HaloCompositionActions {
    var new: @MainActor () -> Void
    var duplicate: (@MainActor () -> Void)?
    var delete: (@MainActor () -> Void)?
}

struct HaloCompositionCommands: Commands {
    @FocusedValue(\.haloCompositionActions) private var actions

    var body: some Commands {
        CommandMenu("Composition") {
            Button("New Composition…", systemImage: "plus") { actions?.new() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(actions == nil)
            Button("Duplicate", systemImage: "plus.square.on.square") { actions?.duplicate?() }
                .keyboardShortcut("d")
                .disabled(actions?.duplicate == nil)
            Button("Delete", systemImage: "trash") { actions?.delete?() }
                .keyboardShortcut(.delete)
                .disabled(actions?.delete == nil)
        }
    }
}
