// HaloWindow+Edit.swift: the history area's routes (Undo, Redo) and hook.
// W0 stub: undo and redo are not built yet (#208), so each does nothing and
// its menu item is disabled with `model.unavailableHelp(for:)` as help.
// history-files replaces this file whole.
import HaloModel
import SwiftUI

extension HaloWindow {
    func editPerform(_ command: HaloCommand) {}

    func editScene(_ content: some View) -> some View { content }
}
