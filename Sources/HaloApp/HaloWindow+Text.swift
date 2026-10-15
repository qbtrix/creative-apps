// HaloWindow+Text.swift: the text area's routes and hook. W0 stub: editing
// text, its size and a layer's color are not built yet (#430), so each
// command does nothing and its control is disabled with
// `model.unavailableHelp(for:)` as help. text-layers replaces this file whole.
import HaloModel
import SwiftUI

extension HaloWindow {
    func textPerform(_ command: HaloCommand) {}

    func textScene(_ content: some View) -> some View { content }
}
