// DesignAnimateMenu.swift: Design's Animate menu. Play/Pause (⌥⌘P) and Stop (⌥⌘.) drive the window's player;
// Set Key (⌥⌘K) and Remove Key (⌥⇧⌘K) key every row (X, Y, Opacity) of the one selected layer at the playhead
// (`menuKeys`). Each item is built from its spec over DesignMenuState, so one that can't act is disabled with its
// reason ("Set a key first." on a still document). Every shortcut carries ⌘: a plain letter or Space would fire while
// a layer's text is being typed, and none clashes with the palette's tool keys (ToolKeys) or another Design menu.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignAnimateMenu: View {
    let menu: DesignMenu

    var body: some View {
        menu.item("animate.play-pause", systemImage: "playpause", shortcut: KeyboardShortcut("p", modifiers: [.option, .command])) {
            menu.perform(.playPause)
        }
        menu.item("animate.stop", systemImage: "stop", shortcut: KeyboardShortcut(".", modifiers: [.option, .command])) {
            menu.perform(.stop)
        }
        Divider()
        menu.item("keyframe.set", systemImage: "plus.diamond", shortcut: KeyboardShortcut("k", modifiers: [.option, .command])) {
            menu.perform(.keys(menu.workspace.menuKeys(removing: false)))
        }
        menu.item("keyframe.remove", systemImage: "minus.diamond",
                  shortcut: KeyboardShortcut("k", modifiers: [.option, .shift, .command])) {
            menu.perform(.keys(menu.workspace.menuKeys(removing: true)))
        }
    }
}
