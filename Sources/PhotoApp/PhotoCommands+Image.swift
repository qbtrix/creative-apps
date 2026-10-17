// PhotoCommands+Image.swift: Photo's Image menu in the menu bar (Image Size…,
// the three rotations and Straighten…), off with no image.
import PhotoModel
import SwiftUI

extension PhotoCommands {
    var imageMenu: some Commands {
        CommandMenu("Image") {
            PhotoImageMenu(perform: menu.perform).disabled(!menu.hasImage)
        }
    }
}

/// The Image menu's items.
struct PhotoImageMenu: View {
    let perform: PhotoPerform

    var body: some View {
        Button("Image Size…") { perform(.imageSize) }
        Divider()
        Button("Rotate 90° Clockwise") { perform(.rotate(.degrees90)) }
        Button("Rotate 90° Counterclockwise") { perform(.rotate(.degrees270)) }
        Button("Rotate 180°") { perform(.rotate(.degrees180)) }
        Button("Straighten…") { perform(.straighten) }
    }
}
