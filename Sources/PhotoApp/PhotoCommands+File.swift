// PhotoCommands+File.swift: Photo's File menu items: New Image, Open…, Open
// Recent ▸, Save, Save As…, Export…. Save, Save As and Export are off with no
// image. Open Recent lists the focused window's recent files, newest first;
// one opens in that window (a file that is gone shows the open error), and
// Clear Menu, disabled with none, empties the list. With no window open it
// lists the saved list (PhotoSavedRecent) and a pick opens in a new window
// through PhotoOpenQueue (PhotoRecentMenu chooses). Replacing `.newItem`
// drops nothing the system would show: a WindowGroup app has no Open Recent
// of its own.
import PhotoModel
import SwiftUI

extension PhotoCommands {
    @CommandsBuilder var fileMenu: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Image") { menu.perform(.newImage) }.keyboardShortcut("n")
            Button("Open…") { menu.perform(.open) }.keyboardShortcut("o")
            Menu("Open Recent") {
                let recent = PhotoRecentMenu(focused: recentFiles, stored: PhotoSavedRecent.shared.files)
                ForEach(recent.files, id: \.self) { url in
                    Button(url.lastPathComponent) { openRecent(url, recent.target) }
                }
                if !recent.files.isEmpty { Divider() }
                Button("Clear Menu") { clearRecent(recent.target) }.disabled(!recent.canClear)
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

    /// A pick opens in the focused window, or with none in a new window.
    func openRecent(_ url: URL, _ target: PhotoRecentMenu.Target) {
        switch target {
        case .focusedWindow: menu.perform(.openFile(url))
        case .noWindow: PhotoOpenQueue.shared.open(url)
        }
    }

    func clearRecent(_ target: PhotoRecentMenu.Target) {
        switch target {
        case .focusedWindow: menu.perform(.file(.clearRecent))
        case .noWindow: PhotoSavedRecent.shared.clear()
        }
    }
}

/// Open Recent's saved list for when no window is open: PhotoFileSession's,
/// reread each time the menu builds, and rebuilt after Clear Menu.
@MainActor @Observable final class PhotoSavedRecent {
    static let shared = PhotoSavedRecent()
    private var clears = 0

    var files: [URL] {
        _ = clears
        return PhotoFileSession.storedRecent()
    }

    /// Empties the saved list and the system's, as a window's Clear Menu does.
    func clear() {
        PhotoFileSession().clearRecent()
        clears += 1
    }
}
