// HaloWindow+Edit.swift: the history and clipboard area's routes and hook.
// Edit > Undo ⌘Z and Redo ⇧⌘Z (HaloEditMenu) arrive here as .undo and
// .redo and call the Model's `undo()` and `redo()` (HaloHistory.swift), which
// step the whole document and do nothing when there is no step. The menu
// titles each for its step ("Undo New Layer") and disables it with
// `model.unavailableHelp(for:)` ("Nothing to undo.") as help. The hook hands
// the menu the window's copy and paste action (clipboard-interop CB-10): Copy Frame
// writes the frame at the playhead as a full-size PNG through HaloPasteboardAdapter
// and the PasteboardBridge; Paste places the pasteboard's image or SVG at the
// playhead, one step. HaloPasteboardState keeps Paste's reason current from the
// bridge's change watch (notifications, never a timer).
import AppKit
import HaloModel
import SuiteShell
import SwiftUI

/// What Edit's Copy Frame and Paste ask the focused window to do.
enum HaloCopyPasteCommand { case copyFrame, paste }

typealias HaloCopyPasteAction = @MainActor (HaloCopyPasteCommand) -> Void

extension FocusedValues {
    /// The focused Halo window's copy and paste action; nil with no Halo window.
    @Entry var haloCopyPaste: HaloCopyPasteAction?
}

/// Why Paste can't run now (nil while it can).
@MainActor @Observable final class HaloPasteboardState {
    static let shared = HaloPasteboardState()
    private(set) var pasteRefusal: String?
    @ObservationIgnored private var watch: PasteboardChangeWatch?

    private init() {
        pasteRefusal = Self.readRefusal()
        watch = PasteboardChangeWatch { [weak self] in self?.refresh() }
    }

    /// Reads the pasteboard again; called after the app writes to it.
    func refresh() {
        let now = Self.readRefusal()
        if now != pasteRefusal { pasteRefusal = now }
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
        content.focusedSceneValue(\.haloCopyPaste, { clipboard($0) })
    }

    /// Copy Frame writes the PNG; Paste places the best offered item. The Model refuses what it can't do.
    func clipboard(_ command: HaloCopyPasteCommand) {
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
