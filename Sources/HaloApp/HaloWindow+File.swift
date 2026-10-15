// HaloWindow+File.swift: the files area's routes and hook, and the window's
// title. W0 stub: Save, Save As…, Open… and Open Recent are not built yet
// (#209), so each does nothing and its menu item is disabled with
// `model.unavailableHelp(for:)` as help. The title is "Halo" until there is a
// composition, then "Untitled Project", as before. history-files replaces
// this file whole: its routes set `request` (.saveAs, .open,
// .confirmUnsaved(then:)) and `fileScene(_:)` presents and clears it.
import HaloModel
import SwiftUI

extension HaloWindow {
    func filePerform(_ command: HaloCommand) {}

    func fileScene(_ content: some View) -> some View { content }

    /// The window's title.
    var fileWindowTitle: String { model.compositions.isEmpty ? "Halo" : "Untitled Project" }
}
