// HaloWindow+Edit.swift: the history and clipboard area's routes and hook.
// Edit > Undo ⌘Z and Redo ⇧⌘Z (HaloEditMenu) arrive here as .undo and
// .redo and call the Model's `undo()` and `redo()` (HaloHistory.swift), which
// step the whole document and do nothing when there is no step. The menu
// titles each for its step ("Undo New Layer") and disables it with
// `model.unavailableHelp(for:)` ("Nothing to undo.") as help. The hook hands
// the menu the window's clipboard action (clipboard-interop CB-10): Copy Frame
// writes the frame at the playhead as a full-size PNG through HaloPasteboardAdapter
// and the PasteboardBridge; Paste places the pasteboard's image or SVG at the
// playhead, one step. HaloPasteboardState keeps Paste's reason current from the
// bridge's change watch (notifications, never a timer) and tracks text focus.
import AppKit
import HaloModel
import SuiteShell
import SwiftUI

/// What Edit's Copy Frame and Paste ask the focused window to do.
enum HaloClipboardCommand { case copyFrame, paste }

typealias HaloClipboardAction = @MainActor (HaloClipboardCommand) -> Void

extension FocusedValues {
    /// The focused Halo window's clipboard action; nil with no Halo window.
    @Entry var haloClipboard: HaloClipboardAction?
}

/// Why Paste can't run now (nil while it can), and whether a text field has focus.
@MainActor @Observable final class HaloPasteboardState {
    static let shared = HaloPasteboardState()
    private(set) var pasteRefusal: String?
    private(set) var isEditingText = false
    @ObservationIgnored private var watch: PasteboardChangeWatch?
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    private init() {
        pasteRefusal = Self.readRefusal()
        watch = PasteboardChangeWatch { [weak self] in self?.refresh() }
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { HaloPasteboardState.shared.refreshFocus() }
        }
    }

    /// Reads the pasteboard again; called after the app writes to it.
    func refresh() {
        let now = Self.readRefusal()
        if now != pasteRefusal { pasteRefusal = now }
    }

    private func refreshFocus() {
        let now = HaloTextFocus.isEditing
        if now != isEditingText { isEditingText = now }
    }

    private static func readRefusal() -> String? {
        HaloPasteboardAdapter().pasteRefusal(for: PasteboardBridge().offered())?.message
    }
}

extension HaloWindow {
    func editPerform(_ command: HaloCommand) {
        switch command {
        case .undo: model.undo()
        case .redo: model.redo()
        default: break
        }
    }

    func editScene(_ content: some View) -> some View {
        content.focusedSceneValue(\.haloClipboard, { clipboard($0) })
    }

    /// Copy Frame writes the PNG; Paste places the best offered item. The Model refuses what it can't do.
    func clipboard(_ command: HaloClipboardCommand) {
        let bridge = PasteboardBridge()
        switch command {
        case .copyFrame:
            guard let items = try? HaloPasteboardAdapter().copyFrame(model) else { return }
            bridge.write(items)
        case .paste:
            takePlayback()
            try? model.paste(bridge.offered())
        }
        HaloPasteboardState.shared.refresh()
    }
}
