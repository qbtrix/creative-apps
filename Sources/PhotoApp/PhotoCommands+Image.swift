// PhotoCommands+Image.swift: Photo's Image menu in the menu bar (Image Size…,
// the three rotations and Straighten…), each from its catalog spec: off with no image.
import PhotoModel
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
        Divider()
        menu.item("image.rotate-cw") { menu.perform(.rotate(.degrees90)) }
        menu.item("image.rotate-ccw") { menu.perform(.rotate(.degrees270)) }
        menu.item("image.rotate-180") { menu.perform(.rotate(.degrees180)) }
        menu.item("image.straighten") { menu.perform(.straighten) }
    }
}
