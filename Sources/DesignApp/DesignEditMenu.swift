// DesignEditMenu.swift: the Design items of the Edit menu, placed after the
// system's own Cut, Copy, Paste, Delete and Select All, which stay so they keep
// working in text fields: Duplicate (⌘D), then SuiteUI's CopyAsMenu (Copy As PNG,
// SVG or Design Layers, and Paste as Image; clipboard-interop CB-6), each off with
// its reason while the workspace can't act. The system's Delete removes the
// selected layer: the canvas and the Layers list hook it (designPasteboardCommands),
// so Edit holds one Delete, not a second look-alike. Also DesignMenu's `item`,
// how every Design menu item is built from its catalog spec (AC-d3): SuiteUI's
// MenuCommand on the spec over DesignMenuState, so it is disabled while the
// spec says why, with that reason as its tooltip.
//
// `designPasteboardCommands` hooks the system's Cut, Copy, Paste and Delete (the stock Edit items and their
// shortcuts) on a focused view, the canvas and the Layers list, to `.cut`, `.copy`, `.paste` and
// `.deleteSelection`, which DesignWindow runs (the first three through DesignPasteboardAdapter and SuiteShell's
// PasteboardBridge, clipboard-interop CB-6). Copy and Cut are off while the Model gives a reason (nothing
// selected, a text edit under way), and Delete while DesignMenu can't delete a layer, so a text field keeps its
// own. A hook hands the system every representation the window just wrote (own layers, SVG, PNG), so whatever
// the system then writes holds the same ones. Paste is on for Design's layers, SVG and the image types.
import DesignModel
import SuiteKernel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI
import UniformTypeIdentifiers

/// Edit: Duplicate, then Enter Group and Exit Group (area-selection AR-14; Return and Escape on the canvas),
/// then Copy As and Paste as Image.
struct DesignEditItems: View {
    let menu: DesignMenu

    var body: some View {
        menu.item("edit.duplicate", systemImage: "plus.square.on.square", shortcut: KeyboardShortcut("d")) {
            menu.perform(.command(.duplicate))
        }
        menu.item("select.enter-group", systemImage: "arrow.down.right.square") { menu.perform(.enterGroup) }
        menu.item("select.exit-group", systemImage: "arrow.up.left.square") { menu.perform(.exitGroup) }
        let perform = menu.perform
        CopyAsMenu(on: menu.workspace, ownTitle: "Design Layers", copy: { perform(.copyAs($0)) },
                   pasteAsImage: { perform(.pasteAsImage) })
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

extension View {
    /// The system's Cut, Copy, Paste and Delete on this view, sent to the window as `.cut`, `.copy`,
    /// `.paste` and `.deleteSelection`.
    func designPasteboardCommands(_ model: DesignWorkspace, _ perform: @escaping DesignPerform) -> some View {
        let type = model.pasteboardType
        let pastes = [UTType(importedAs: type)] + DesignPasteboardAdapter.pictureTypes.compactMap { UTType($0.rawValue) }
        let canCopy = model.copyHelp() == nil
        let canDelete = DesignMenu.deletesLayer(model)
        // Each runs the intent, then reads back what the window wrote, on the main actor.
        let copied: @MainActor () -> [TypedData] = { perform(.copy); return PasteboardBridge().offered() }
        let cut: @MainActor () -> [TypedData] = { perform(.cut); return PasteboardBridge().offered() }
        return self
            .onCopyCommand(perform: canCopy ? { designItemProviders(MainActor.assumeIsolated(copied)) } : nil)
            .onCutCommand(perform: canCopy ? { designItemProviders(MainActor.assumeIsolated(cut)) } : nil)
            .onPasteCommand(of: pastes) { _ in MainActor.assumeIsolated { perform(.paste) } }
            .onDeleteCommand(perform: canDelete ? { MainActor.assumeIsolated { perform(.deleteSelection) } } : nil)
    }
}

/// Every representation in `offered` as one item provider for a SwiftUI pasteboard hook; empty for none.
private func designItemProviders(_ offered: [TypedData]) -> [NSItemProvider] {
    guard !offered.isEmpty else { return [] }
    let provider = NSItemProvider()
    for rep in offered {
        let data = rep.data
        provider.registerDataRepresentation(forTypeIdentifier: rep.type.rawValue, visibility: .all) { load in
            load(data, nil)
            return nil
        }
    }
    return [provider]
}
