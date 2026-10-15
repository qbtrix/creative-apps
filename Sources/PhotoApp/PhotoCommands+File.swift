// PhotoCommands+File.swift: Photo's File menu items: New Image, Open…, Open
// Recent ▸, Save, Save As…, Export…. Save, Save As and Export are off with no
// image. Open Recent lists the focused window's recent files, newest first;
// one opens in that window (a file that is gone shows the open error), and
// Clear Menu, disabled with none, empties the list. Replacing `.newItem`
// drops nothing the system would show: a WindowGroup app has no Open Recent
// of its own.
import SwiftUI

extension PhotoCommands {
    @CommandsBuilder var fileMenu: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Image") { menu.perform(.newImage) }.keyboardShortcut("n")
            Button("Open…") { menu.perform(.open) }.keyboardShortcut("o")
            Menu("Open Recent") {
                let recent = recentFiles ?? []
                ForEach(recent, id: \.self) { url in
                    Button(url.lastPathComponent) { menu.perform(.openFile(url)) }
                }
                if !recent.isEmpty { Divider() }
                Button("Clear Menu") { menu.perform(.file(.clearRecent)) }.disabled(recent.isEmpty)
            }
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
