// HaloWindow+Easing.swift: the easing area's routes and hook. W0 stub: key
// selection and easing are not built yet (#428), so each command does nothing
// and its control is disabled with `model.unavailableHelp(for:)` as help.
// easing replaces this file whole.
import HaloModel
import SwiftUI

extension HaloWindow {
    func easingPerform(_ command: HaloCommand) {}

    func easingScene(_ content: some View) -> some View { content }
}
