// HaloWindow+Render.swift: the render area's routes and hook. W0 stub:
// Render Frame and Render… are not built yet (#451, #429), so each command
// does nothing and its control is disabled with `model.unavailableHelp(for:)`
// as help. render-out replaces this file whole; its `renderScene(_:)`
// presents the render sheet.
import HaloModel
import SwiftUI

extension HaloWindow {
    func renderPerform(_ command: HaloCommand) {}

    func renderScene(_ content: some View) -> some View { content }
}
