// FlarePlace.swift (svg-place PF-3): File > Place… (Shift-Command-P) opens PlacePanel limited to the place formats
// (SVG); it and the window's drop place centred through the workspace (FlarePlace+Menu.swift), shown in the status line.
import FlareModel
import SuiteUI
import SwiftUI

extension FlareWindow {
    /// File > Place…: the panel, then each chosen file, centred. Cancel chooses nothing and changes nothing.
    func choosePlace() {
        Task { @MainActor in _ = place(await PlacePanel.choose(formats: model.placeFormats)) }
    }

    /// Places `files` centred in the scene; nothing to place does nothing. Returns whether there was anything.
    func place(_ files: [(name: String, data: Data)]) -> Bool {
        guard !files.isEmpty else { return false }
        model.place(files)
        return true
    }
}
