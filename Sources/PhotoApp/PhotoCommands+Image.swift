// PhotoCommands+Image.swift: Photo's Image menu, the same items as the top
// bar's Image menu (PhotoImageMenu in PhotoEditor.swift), off with no image.
import SwiftUI

extension PhotoCommands {
    var imageMenu: some Commands {
        CommandMenu("Image") {
            PhotoImageMenu(perform: menu.perform).disabled(!menu.hasImage)
        }
    }
}
