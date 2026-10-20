// PhotoCommands+Image.swift: Photo's Image menu in the menu bar (Image Size…,
// Canvas Size…, the three rotations and Straighten…), each from its catalog
// spec: off with no image. Canvas Size…'s spec is local until PT-6 registers
// `image.canvas-size` in Photo's catalog.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

extension PhotoCommands {
    var imageMenu: some Commands {
        CommandMenu("Image") {
            PhotoImageMenu(menu: menu)
        }
    }
}

/// The Image menu's items.
struct PhotoImageMenu: View {
    let menu: PhotoMenu

    /// Canvas Size…: opens its sheet (transform PT-3); off with no image.
    static let canvasSizeSpec = CommandSpec<PhotoWorkspace>.typed(
        "image.canvas-size", title: "Canvas Size…", summary: "Grows or crops the canvas around an anchor without scaling the image.",
        kind: .edit, params: JSONValue.self, example: .object([:]),
        availability: { $0.canvas == nil ? .unavailable("Open an image first.") : .available }
    ) { _, _ in JSONValue.object([:]) }

    var body: some View {
        menu.item("image.resize") { menu.perform(.imageSize) }
        MenuCommand(Self.canvasSizeSpec, on: menu.workspace) { menu.perform(.transform(.canvasSize)) }
        Divider()
        menu.item("image.rotate-cw") { menu.perform(.rotate(.degrees90)) }
        menu.item("image.rotate-ccw") { menu.perform(.rotate(.degrees270)) }
        menu.item("image.rotate-180") { menu.perform(.rotate(.degrees180)) }
        menu.item("image.straighten") { menu.perform(.straighten) }
    }
}
