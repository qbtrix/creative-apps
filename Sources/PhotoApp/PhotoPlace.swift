// PhotoPlace.swift (place-image PP-3): File > Place… (Shift-Command-P) and the canvas drop. Place… opens SuiteUI's
// PlacePanel limited to PNG and JPEG and places what it chose, centred; a PNG or JPEG dropped on an open image
// places at the drop point (PhotoCanvas's `placeDropTarget`). Both run `place.image` through the workspace
// (PhotoPlace+Menu.swift), whose refusal shows in the status line. The item is built from `place.image`'s
// spec, so it is off with its reason while the command can't run: no image open, or the PP-1 stubs.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// What Place asks the window to do.
enum PhotoPlaceIntent {
    /// File > Place…: the panel, then each chosen file, centred.
    case choose
    /// Files dropped on the canvas, at the drop point in document pixels.
    case files([(name: String, data: Data)], at: Point?)
}

extension PhotoWindow {
    func performPlace(_ intent: PhotoPlaceIntent) {
        switch intent {
        case .choose:
            Task {
                let files = await PlacePanel.choose(formats: model.placeFormats)
                model.place(files, at: nil)
            }
        case .files(let files, let at): model.place(files, at: at)
        }
    }
}

extension PhotoMenu {
    /// File > Place…: built from `place.image`'s spec, so it is off saying why while the command can't run.
    var placeItem: MenuCommand {
        MenuCommand(PhotoWorkspace.placeMenuSpec, on: workspace, title: "Place…",
                    shortcut: KeyboardShortcut("p", modifiers: [.command, .shift])) { perform(.place(.choose)) }
    }
}
