// HaloWindow+Keys.swift: the keys area's routes and hook. W0 stub: no
// TRANSFORM row, stopwatch, key, Parent, Blend or viewer drag is built yet
// (#38), so each command does nothing and its control is disabled with
// `model.unavailableHelp(for:)` as help. layer-keys replaces this file whole,
// keeping `keysScene(_:)`.
import HaloModel
import SwiftUI

extension HaloWindow {
    func keysPerform(_ command: HaloCommand) {}

    func keysScene(_ content: some View) -> some View { content }
}
