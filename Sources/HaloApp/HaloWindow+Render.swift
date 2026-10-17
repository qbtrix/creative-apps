// HaloWindow+Render.swift: the render area's routes and hook. Render Frame
// (⌘R, render-out RO-5, #451) calls the Model's `renderCurrentFrame()`, and
// the viewer shows the frame (HaloRenderedFrameView). Render… and the render
// job's commands are not built yet (#429): each does nothing here and its
// control is disabled with `model.unavailableHelp(for:)` as help.
// `renderScene(_:)` is a pass-through until RO-8 presents the render sheet.
import HaloModel
import SwiftUI

extension HaloWindow {
    func renderPerform(_ command: HaloCommand) {
        switch command {
        case .renderFrame: model.renderCurrentFrame()
        default: break
        }
    }

    func renderScene(_ content: some View) -> some View { content }
}
