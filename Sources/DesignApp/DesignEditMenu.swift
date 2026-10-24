// DesignEditMenu.swift: the Design items of the Edit menu, placed after the
// system's own Cut, Copy, Paste, Delete and Select All, which stay so they keep
// working in text fields: Duplicate (⌘D). The system's Delete removes the
// selected layer: the canvas and the Layers list hook it (designPasteboardCommands),
// so Edit holds one Delete, not a second look-alike. Also DesignMenu's `item`,
// how every Design menu item is built from its catalog spec (AC-d3): SuiteUI's
// MenuCommand on the spec over DesignMenuState, so it is disabled while the
// spec says why, with that reason as its tooltip.
import DesignModel
import SuiteUI
import SwiftUI

/// Edit: Duplicate, then Enter Group and Exit Group (area-selection AR-14; Return and Escape on the canvas).
struct DesignEditItems: View {
    let menu: DesignMenu

    var body: some View {
        menu.item("edit.duplicate", systemImage: "plus.square.on.square", shortcut: KeyboardShortcut("d")) {
            menu.perform(.command(.duplicate))
        }
        menu.item("select.enter-group", systemImage: "arrow.down.right.square") { menu.perform(.enterGroup) }
        menu.item("select.exit-group", systemImage: "arrow.up.left.square") { menu.perform(.exitGroup) }
    }
}

extension DesignMenu {
    /// What the items read: this window's workspace, with a focused field's own undo when Undo and Redo go there.
    func state(field: DesignMenuState.FieldUndo? = nil) -> DesignMenuState {
        DesignMenuState(workspace: workspace, hasWindow: hasWindow, field: field)
    }

    /// The menu item for catalog command `id`: the spec's title unless `title` names more, on when the spec can run.
    func item(
        _ id: String, title: String? = nil, systemImage: String, shortcut: KeyboardShortcut? = nil,
        in state: DesignMenuState? = nil, perform: @escaping @MainActor () -> Void
    ) -> MenuCommand {
        MenuCommand(DesignMenuState.spec(id), on: state ?? self.state(), title: title, systemImage: systemImage,
                    shortcut: shortcut, perform: perform)
    }
}
