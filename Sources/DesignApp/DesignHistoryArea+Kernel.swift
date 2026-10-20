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
struct DesignHistoryShown {
    var isShown: Bool
    var toggle: @MainActor () -> Void
}

/// A plain key rather than `@Entry`, as DesignMenuKey is, so DesignApp builds without the macro plugin.
private struct DesignHistoryShownKey: FocusedValueKey {
    typealias Value = DesignHistoryShown
}

extension FocusedValues {
    /// The focused Design window's History panel; nil with no Design window focused.
    var designHistoryPanel: DesignHistoryShown? {
        get { self[DesignHistoryShownKey.self] }
        set { self[DesignHistoryShownKey.self] = newValue }
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
            .focusedSceneValue(\.designHistoryPanel, DesignHistoryShown(isShown: isShown) { isShown.toggle() })
            .autosaveRecovery(hooks, folder: nil, delay: 2, edits: model.documentSession.currentToken)
    }

    private var hooks: AutosaveHooks {
        let model = self.model
        let name = model.documentURL?.lastPathComponent
        let restore = self.restore
        return AutosaveHooks(
            window: window, documentName: { name }, isDirty: { model.isDirty },
            encoder: { Self.encoder(model) },
            restore: { data in try restore(data, name) })
    }

    /// The encode of `model`'s recovery bytes, run off main on this copy; nil with nothing open. A
    /// named function rather than a ternary in the closure, which the type checker gave up on.
    private static func encoder(_ model: DesignWorkspace) -> (@Sendable () throws -> Data)? {
        guard model.isOpen else { return nil }
        return { try model.recoveryBytes() }
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
