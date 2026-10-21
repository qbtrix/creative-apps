// PhotoPlace.swift (place-image PP-3): File > Place… (Shift-Command-P) and the canvas drop. Place… opens SuiteUI's
// PlacePanel limited to PNG and JPEG and places what it chose, centred; a PNG or JPEG dropped on an open image
// places at the drop point (PhotoCanvas's `placeDropTarget`). Both run `place.image` through the workspace
// (PhotoPlace+Menu.swift), whose refusal shows in the status line. The item is built from the `place.image` spec,
// so it is off with the spec's reason while no image is open or the PP-1 stubs can't run.
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
    /// SuiteKernel's `place.image` spec for Photo; nil only if the kernel drops it.
    static let placeSpec = PlaceCommands.specs(PhotoWorkspace.self).first { $0.id == "place.image" }

    /// File > Place…: the spec decides whether it is on and what its help says (the panel is built, so it adds no reason).
    @ViewBuilder var placeItem: some View {
        if let spec = Self.placeSpec {
            MenuCommand(spec, on: workspace, title: "Place…", shortcut: KeyboardShortcut("p", modifiers: [.command, .shift])) {
                perform(.place(.choose))
            }
        }
    }
}
