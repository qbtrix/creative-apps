// DesignHistoryArea+Kernel.swift: the History panel and the autosave hooks on a Design window
// (design/autosave-history DA-2). DesignHistoryArea keeps whether the panel shows as its own
// state, so toggling it never runs the window's body, and publishes that to View > Show History
// as the focused scene value `designHistoryPanel`. Shown, SuiteUI's HistoryPanel sits in a
// GlassPanel inset at the window's trailing edge on the workspace's `historyListing`; a click or
// Return hands the state to `jump`, and a refusal goes to the status line through `onNote`.
// `.autosaveRecovery` reads the workspace through AutosaveHooks: the open file's name, whether it
// is dirty, its `recoveryBytes()` and `restore` for a copy left behind. The modifier and the
// adapter (DesignRecovery+Kernel.swift) are stubs until AH-8 and DA-5, so the panel lists the
// steps but a jump says History isn't built yet, and nothing is written. `panel` is the panel
// alone, which DesignEditorSnapshots renders.
import DesignModel
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI

/// Whether the focused window's History panel shows, and how to toggle it.
struct DesignHistoryToggle {
    var isShown: Bool
    var toggle: @MainActor () -> Void
}

/// A plain key rather than `@Entry`, as DesignMenuKey is, so DesignApp builds without the macro plugin.
private struct DesignHistoryToggleKey: FocusedValueKey {
    typealias Value = DesignHistoryToggle
}

extension FocusedValues {
    /// The focused Design window's History panel; nil with no Design window focused.
    var designHistoryPanel: DesignHistoryToggle? {
        get { self[DesignHistoryToggleKey.self] }
        set { self[DesignHistoryToggleKey.self] = newValue }
    }
}

struct DesignHistoryArea: ViewModifier {
    let model: DesignWorkspace
    /// Lands the workspace on a listed state.
    let jump: @MainActor (Int) throws -> Void
    /// Puts a recovered copy's bytes in the window, named for the file it was.
    let restore: @MainActor (Data, String?) throws -> Void
    let onNote: @MainActor (String) -> Void
    /// The window's id, which names its recovery files.
    @State private var window = UUID().uuidString
    @State private var isShown = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .trailing, spacing: 0) {
                if isShown { Self.panel(model.historyListing, onJump: jumped) }
            }
            .focusedSceneValue(\.designHistoryPanel, DesignHistoryToggle(isShown: isShown) { isShown.toggle() })
            .autosaveRecovery(hooks, folder: nil, delay: 2, edits: model.documentSession.currentToken)
    }

    private var hooks: AutosaveHooks {
        let name = model.documentURL?.lastPathComponent
        return AutosaveHooks(
            window: window, documentName: { name }, isDirty: { [model] in model.isDirty },
            encoder: { [model] in model.isOpen ? { try model.recoveryBytes() } : nil },
            restore: { [restore] data in try restore(data, name) })
    }

    /// A row's jump; a refusal goes to the status line.
    private func jumped(_ index: Int) {
        do { try jump(index) } catch { onNote((error as? DesignRefusal)?.help ?? "\(error)") }
    }

    /// The panel on `listing`, at the editor's panel width, inset from the window's edge.
    @MainActor static func panel(_ listing: HistoryListing, onJump: @escaping @MainActor (Int) -> Void) -> some View {
        GlassPanel {
            HistoryPanel(listing: listing, onJump: onJump)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: SuiteSize.editorPanelWidth)
        .padding(SuiteSpacing.s)
    }
}
