// FlareCommands.swift: Flare's menu bar. File > New Sample Animation opens the
// keyed Ball document, the route into the easing editor until Flare can key by
// hand (#204). Edit > Undo and Redo act on the focused window's FlareWorkspace
// and are named for the step, as in "Undo Set Keyframe Easing". The focused
// window publishes a FlareMenu as a focused scene value; with no Flare window
// focused, or nothing to undo or redo, an item disables rather than hides.
import FlareModel
import SwiftUI

/// What the focused Flare window's menus can do now.
struct FlareMenu {
    var newSample: @MainActor () -> Void = {}
    var undo: @MainActor () -> Void = {}
    var redo: @MainActor () -> Void = {}
    var canUndo = false
    var canRedo = false
    var undoTitle = "Undo"
    var redoTitle = "Redo"

    init() {}

    init(
        model: FlareWorkspace, newSample: @escaping @MainActor () -> Void, undo: @escaping @MainActor () -> Void,
        redo: @escaping @MainActor () -> Void
    ) {
        self.newSample = newSample
        self.undo = undo
        self.redo = redo
        canUndo = model.canUndo
        canRedo = model.canRedo
        undoTitle = model.undoActionName ?? "Undo"
        redoTitle = model.redoActionName ?? "Redo"
    }
}

extension FocusedValues {
    /// The focused Flare window's menu; nil with no Flare window focused.
    var flareMenu: FlareMenu? {
        get { self[FlareMenuKey.self] }
        set { self[FlareMenuKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, so FlareApp builds without the SwiftUI
/// macro plugin (Command Line Tools).
private struct FlareMenuKey: FocusedValueKey {
    typealias Value = FlareMenu
}

struct FlareCommands: Commands {
    @FocusedValue(\.flareMenu) private var focused

    private var menu: FlareMenu { focused ?? FlareMenu() }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Sample Animation", systemImage: "wand.and.stars") { menu.newSample() }
                .disabled(focused == nil)
        }
        CommandGroup(replacing: .undoRedo) {
            Button(menu.undoTitle) { menu.undo() }.keyboardShortcut("z").disabled(!menu.canUndo)
            Button(menu.redoTitle) { menu.redo() }.keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!menu.canRedo)
        }
    }
}
