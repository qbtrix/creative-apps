// PhotoPlace.swift (place-image PP-3, file-flow PF-2): File > Place… (Shift-Command-P) and the window's file drop.
// Place… opens SuiteUI's PlacePanel limited to PNG and JPEG and places what it chose, centred, through `place.image`
// (PhotoPlace+Menu.swift), whose refusal shows in the status line. The item is built from the `place.image` spec, so
// it is off with the spec's reason while no image is open. A drop on the window (PhotoEditor's `suiteFileDrop`) comes
// as the suite's planned actions: the workspace places the images as layers in one Place step, centred; a file to
// open opens here when no image is, else in a new window; another app's file is handed to that app. `files` places
// bytes already read (a test's, or a caller's with no file on disk), centred or at a document point. Every place
// reads its images through ImageIO, straight at the size they're placed at (#4248).
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// What Place asks the window to do.
enum PhotoPlaceIntent {
    /// File > Place…: the panel, then each chosen file, centred.
    case choose
    /// Files dropped on the window, planned by the suite's drop rule.
    case drop([DropAction])
    /// Image bytes already read, centred or at `at` in document pixels.
    case files([(name: String, data: Data)], at: Point?)
}

extension PhotoWindow {
    func performPlace(_ intent: PhotoPlaceIntent) {
        model.readImages(with: ImageIOCodec())
        switch intent {
        case .choose:
            Task {
                let files = await PlacePanel.choose(formats: model.placeFormats)
                model.place(files, at: nil)
            }
        case .drop(let actions):
            do {
                try model.perform(actions)
            } catch {
                let message = if case CatalogError.failed(_, let text) = error { text } else { Self.reason(error) }
                problem = PhotoProblem("The drop can't be placed.", message)
            }
            for request in model.takeFileRequests() {
                switch request {
                case .open(let path):
                    let url = URL(fileURLWithPath: path)
                    if model.canvas == nil { open(url) } else { PhotoOpenQueue.shared.open(url) }
                case .handOff(let path, let app):
                    Task { await PhotoShell.bridge.handOff([.handOff(path: path, app: app)]) }
                case .forget, .clearRecent: continue
                }
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
