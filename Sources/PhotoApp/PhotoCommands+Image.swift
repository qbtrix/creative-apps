// PhotoCommands+Image.swift: Photo's Image menu in the menu bar (Image Size…,
// Canvas Size…, the three rotations, Flip Canvas Horizontal and Vertical, both
// from the `image.flip` spec (orientation-crop OC-13), and Straighten…), each
// from its catalog spec: off with no image, and Canvas Size… and the flips
// also while Free Transform is open.
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

    var body: some View {
        menu.item("image.resize") { menu.perform(.imageSize) }
        menu.item("image.canvas-size") { menu.perform(.transform(.canvasSize)) }
        Divider()
        menu.item("image.rotate-cw") { menu.perform(.rotate(.degrees90)) }
        menu.item("image.rotate-ccw") { menu.perform(.rotate(.degrees270)) }
        menu.item("image.rotate-180") { menu.perform(.rotate(.degrees180)) }
        menu.item("image.flip", title: "Flip Canvas Horizontal") { menu.perform(.flipCanvas(.horizontal)) }
        menu.item("image.flip", title: "Flip Canvas Vertical") { menu.perform(.flipCanvas(.vertical)) }
        menu.item("image.straighten") { menu.perform(.straighten) }
        Divider()
        PhotoAdjustmentsMenu()
    }
}
