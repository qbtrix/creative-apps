// FlareStageContextMenu.swift: the stage's context menu (stage-edit SE-3): Cut, Copy, Duplicate, Delete, then
// Bring Forward and Send Backward. Each item is the Edit or Object menu's intent through `perform`, on its catalog
// spec (command-state CS-12) and disabled with `FlareWindow.editHelp`'s reason as its help while it can't act. It also
// publishes the pasteboard's change count from SuiteShell's PasteboardChangeWatch, so the Edit menu's Paste follows the
// system pasteboard: the watch looks when a menu opens or the window becomes key, never on a timer (clipboard-interop CB-8).
import FlareModel
import SuiteShell
import SuiteUI
import SwiftUI

struct FlareStageContextMenu: ViewModifier {
    let model: FlareWorkspace
    let zoom: Double
    let perform: @MainActor (FlareIntent) -> Void
    @State private var pasteboardChange = 0
    @State private var watch: PasteboardChangeWatch?

    func body(content: Content) -> some View {
        content
            .contextMenu {
                item(.cut)
                item(.copy)
                item(.duplicate)
                item(.delete)
                Divider()
                item(.bringForward)
                item(.sendBackward)
            }
            .focusedSceneValue(\.flarePasteboardChange, pasteboardChange)
            .onAppear {
                pasteboardChange = PasteboardBridge().changeCount
                watch = PasteboardChangeWatch { pasteboardChange = PasteboardBridge().changeCount }
            }
            .onDisappear { watch = nil }
    }

    private func item(_ intent: FlareIntent.Edit) -> some View {
        let reason = FlareWindow.editHelp(intent, in: model, pasteboard: [])
        return MenuCommand(FlareWorkspace.menuSpec(for: .edit(intent)), on: reason, title: FlareIntent.edit(intent).title) {
            perform(.edit(intent))
        }
    }
}
