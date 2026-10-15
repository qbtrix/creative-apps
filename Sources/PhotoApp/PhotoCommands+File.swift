// PhotoCommands+File.swift: Photo's File menu items: New Image, Open…, Save,
// Save As…, Export…. Save, Save As and Export are off with no image.
import SwiftUI

extension PhotoCommands {
    @CommandsBuilder var fileMenu: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Image") { menu.perform(.newImage) }.keyboardShortcut("n")
            Button("Open…") { menu.perform(.open) }.keyboardShortcut("o")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { menu.perform(.save) }.keyboardShortcut("s").disabled(!menu.hasImage)
            Button("Save As…") { menu.perform(.saveAs) }.keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!menu.hasImage)
            Button("Export…") { menu.perform(.export(.openSheet)) }.keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!menu.hasImage)
        }
    }
}
