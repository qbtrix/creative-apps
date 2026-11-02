// FlareCommands.swift: Flare's menu bar, docs/blueprints/flare.md section
// 3.4. Every item is one FlareIntent: it acts through the focused window's
// `perform` and is disabled while that window's `help` gives a reason (shown as
// the item's help). The beta hides the items of FlareWorkspace.menuHidden
// (onion skin, motion path, the symbol edits, Interactions, Assist), keys and all. The keys of section 3.4 (Space, the
// arrows, Home, End, K, ⌥K and the ⌘ keys) live only here; no view binds them
// again. Return and Escape stay the stage's (toolKey); Object > Finish Path is
// Return's item for the mouse, with no key of its own. Undo and Redo are
// titled by the step, as in "Undo Set Keyframe Easing". File > Open Sample
// lists Bounce, Character, Button and Keyed Ball, the keyed document the
// easing journey starts from; Open Recent lists the window's recent files,
// then Clear Menu. File > Place… (⇧⌘P, svg-place PF-3) is off with
// `place.image`'s reason until an animation is open. Document Settings… opens
// the shared setup sheet on the open scene. The focused window publishes a FlareMenu as a focused
// scene value (FlareWindow.swift); with none focused every item disables. The
// value carries the selection's Edit reasons too, so a new selection is a new
// value and the items re-read their reasons. ⌘A is Select All Keys while the
// timeline strip has focus (its FocusedValues.timelineSelectAll, key-select-all
// KS-2), else Edit > Select All on the stage's art. While a text field has
// focus (FILL's hex field, a layer name), Undo, Redo, Cut, Copy, Paste, Delete
// and Select All give way to it (SuiteUI's MenuCommand.givingWay, #4830).
import FlareModel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

/// What the focused Flare window's menus can do now.
struct FlareMenu {
    var perform: @MainActor (FlareIntent) -> Void = { _ in }
    var help: @MainActor (FlareIntent) -> String? = { _ in "Open a Flare window first." }
    var undoTitle = "Undo"
    var redoTitle = "Redo"
    var loops = false
    /// The selection's Edit reasons as values (#2618). `help` is a closure, which never reads as a changed menu,
    /// so without these a LAYERS pick left Edit > Copy disabled with its launch reason until something else
    /// (an undo title, the pasteboard) changed.
    var editHelps: [FlareEditAction: String] = [:]
    /// The keyframe Delete reason (`deleteHelp`), then Bring Forward's and Send Backward's.
    var selectionHelps: [String?] = []
    /// Why File > Place… can't run (`place.image`'s reason), and the panel it opens (FlarePlace.swift).
    var placeHelp: String? = "Open a Flare window first."
    var place: @MainActor () -> Void = {}
    /// The open animation's file, which File > Open In ▸ hands to another app; nil before it has one (file-flow FL-2).
    var document: SuiteDocumentRef?
    /// File > Document Settings… (document-setup DS-14): shows the shared sheet in settings mode; `settingsHelp` is
    /// why it can't, nil when a scene is open.
    var documentSettings: @MainActor () -> Void = {}
    var settingsHelp: String? = "Open a Flare window first."

    /// Open Sample's items: the sample's name for `.openSample(name:)`, and its title.
    static let samples: [(name: String, title: String)] = [
        ("bounce", "Bounce"), ("character", "Character"), ("button", "Button"), ("keyed", "Keyed Ball"),
    ]
}

extension FocusedValues {
    /// The focused Flare window's menu; nil with no Flare window focused.
    var flareMenu: FlareMenu? {
        get { self[FlareMenuKey.self] }
        set { self[FlareMenuKey.self] = newValue }
    }

    /// The system pasteboard's change count as the focused Flare window last saw it (FlareStageContextMenu).
    var flarePasteboardChange: Int? {
        get { self[FlarePasteboardChangeKey.self] }
        set { self[FlarePasteboardChangeKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, so FlareApp builds without the SwiftUI
/// macro plugin (Command Line Tools).
private struct FlareMenuKey: FocusedValueKey {
    typealias Value = FlareMenu
}

/// A plain key rather than `@Entry`, as FlareMenuKey.
private struct FlarePasteboardChangeKey: FocusedValueKey {
    typealias Value = Int
}

struct FlareCommands: Commands {
    @FocusedValue(\.flareMenu) private var focused
    /// Read so a pasteboard change re-runs the body and Paste's reason (FlareStageContextMenu publishes it).
    @FocusedValue(\.flarePasteboardChange) private var pasteboardChange
    /// The focused timeline strip's Select All Keys; nil unless the strip has focus.
    @FocusedValue(\.timelineSelectAll) private var timelineSelectAll

    private var menu: FlareMenu {
        _ = pasteboardChange
        return focused ?? FlareMenu()
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            item(.file(.new), key: KeyboardShortcut("n"))
            item(.file(.open), key: KeyboardShortcut("o"))
        }
        suiteFileMenu
        CommandGroup(replacing: .saveItem) {
            // Open Sample ▸ heads this group: a `before: .saveItem` group is dropped once Save is replaced.
            Menu("Open Sample") {
                ForEach(FlareMenu.samples, id: \.name) { sample in
                    item(.file(.openSample(name: sample.name)), title: sample.title)
                }
            }
            item(.file(.save), key: KeyboardShortcut("s"))
            item(.file(.saveAs), key: KeyboardShortcut("s", modifiers: [.command, .shift]))
            item(.export(.showSheet), key: KeyboardShortcut("e", modifiers: [.command, .shift]))
            if let spec = FlareWorkspace.menuSpec("document.set-settings") {
                MenuCommand(spec, on: menu.settingsHelp, title: "Document Settings…") { menu.documentSettings() }
            }
            item(.file(.close), key: KeyboardShortcut("w"))
        }
        CommandGroup(replacing: .undoRedo) {
            item(.edit(.undo), title: menu.undoTitle, key: KeyboardShortcut("z")).givingWay(to: .undo)
            item(.edit(.redo), title: menu.redoTitle, key: KeyboardShortcut("z", modifiers: [.command, .shift])).givingWay(to: .redo)
        }
        CommandGroup(replacing: .pasteboard) {
            item(.edit(.cut), key: KeyboardShortcut("x")).givingWay(to: .cut)
            item(.edit(.copy), key: KeyboardShortcut("c")).givingWay(to: .copy)
            item(.edit(.paste), key: KeyboardShortcut("v")).givingWay(to: .paste)
            item(.edit(.duplicate), key: KeyboardShortcut("d"))
            item(.edit(.delete), key: KeyboardShortcut(.delete, modifiers: [])).givingWay(to: .delete)
            if let keys = timelineSelectAll, let spec = FlareWorkspace.menuSpec("timeline.select-all-keys") {
                MenuCommand(spec, on: menu.help(.timeline(.selectAllKeys)), shortcut: KeyboardShortcut("a")) { keys.run() }
                    .givingWay(to: .selectAll)
            } else {
                item(.edit(.selectAll), key: KeyboardShortcut("a")).givingWay(to: .selectAll)
            }
            item(.edit(.deselect), key: KeyboardShortcut("a", modifiers: [.command, .shift]))
        }
        CommandGroup(before: .toolbar) {
            item(.view(.zoomIn), key: KeyboardShortcut("+"))
            item(.view(.zoomOut), key: KeyboardShortcut("-"))
            item(.view(.fit), key: KeyboardShortcut("0"))
            item(.view(.actualSize), key: KeyboardShortcut("1"))
            if shown(.view(.toggleOnion)) { item(.view(.toggleOnion)) }
            if shown(.view(.toggleMotionPath)) { item(.view(.toggleMotionPath)) }
            item(.view(.toggleRulers), key: KeyboardShortcut("r"))
            item(.view(.toggleGuides), key: KeyboardShortcut(";"))
            item(.view(.clearGuides))
            Divider()
        }
        CommandMenu("Object") {
            if shown(.library(.convertToSymbol(name: ""))) { item(.library(.convertToSymbol(name: ""))) }
            // Edit Symbol pairs with Exit Symbol: the beta hides both.
            if shown(.library(.exitSymbol)) {
                item(.library(.edit(id: "")))
                item(.library(.exitSymbol))
            }
            if shown(.library(.convertToSymbol(name: ""))) || shown(.library(.exitSymbol)) { Divider() }
            item(.edit(.bringForward), key: KeyboardShortcut("]"))
            item(.edit(.sendBackward), key: KeyboardShortcut("["))
            Divider()
            // No key: Return stays the stage's (toolKey), so a text field's Return is never taken.
            item(.tools(.finishPath))
        }
        CommandMenu("Animate") { animate }
        CommandGroup(before: .windowSize) {
            if shown(.interactions(.toggleEditor)) {
                item(.interactions(.toggleEditor))
                Divider()
            }
        }
    }

    /// The suite's Open Recent ▸ and Open In ▸, after Open… (file-flow FL-2), File > Place… (svg-place PF-u),
    /// and the File items Flare hides; Open Sample ▸ opens the Save group in `body`, as section 3.4 orders File (#4604).
    /// Its own builder keeps `body` within the builder's ten top-level commands.
    @CommandsBuilder private var suiteFileMenu: some Commands {
        SuiteFileCommands(app: .flare, bridge: FlareShell.bridge, document: menu.document)
        CommandGroup(replacing: .importExport) {
            MenuCommand(FlareWorkspace.placeMenuSpec, on: menu.placeHelp,
                        shortcut: KeyboardShortcut("p", modifiers: [.command, .shift])) { menu.place() }
        }
        CommandGroup(replacing: .printItem) {}
    }

    /// Animate: Play/Pause … Animate with Assist…, section 3.4's order.
    @ViewBuilder private var animate: some View {
        item(.timeline(.togglePlay), key: KeyboardShortcut(.space, modifiers: []))
        // A checked item: Loop shows whether playback wraps.
        Toggle(
            FlareIntent.timeline(.setLoops(true)).title,
            isOn: Binding(get: { menu.loops }, set: { on in menu.perform(.timeline(.setLoops(on))) })
        )
        .disabled(menu.help(.timeline(.setLoops(!menu.loops))) != nil)
        item(.timeline(.step(1)), key: KeyboardShortcut(.rightArrow, modifiers: []))
        item(.timeline(.step(-1)), key: KeyboardShortcut(.leftArrow, modifiers: []))
        item(.timeline(.nextKeyframe), key: KeyboardShortcut(.rightArrow, modifiers: .option))
        item(.timeline(.previousKeyframe), key: KeyboardShortcut(.leftArrow, modifiers: .option))
        item(.timeline(.goToStart), key: KeyboardShortcut(.home, modifiers: []))
        item(.timeline(.goToEnd), key: KeyboardShortcut(.end, modifiers: []))
        Divider()
        item(.timeline(.addKey), key: KeyboardShortcut("k", modifiers: []))
        item(.timeline(.removeKey), key: KeyboardShortcut("k", modifiers: .shift))
        item(.timeline(.toggleAutoKey), key: KeyboardShortcut("k", modifiers: .option))
        item(.timeline(.insertFrames(1)), key: KeyboardShortcut("=", modifiers: .option))
        item(.timeline(.removeFrames(1)), key: KeyboardShortcut("-", modifiers: .option))
        item(.timeline(.setLabel(nil)))
        Menu("Easing") {
            ForEach(EasingPreset.allCases, id: \.self) { preset in
                item(.inspector(.easingPreset(preset.rawValue)), title: preset.title)
            }
        }
        if shown(.assist(.showPopover)) {
            Divider()
            item(.assist(.showPopover))
        }
    }

    /// False for an item the beta hides: its command is in `FlareWorkspace.menuHidden` (no-placeholders NP-4).
    private func shown(_ intent: FlareIntent) -> Bool {
        !(intent.commandID.map(FlareWorkspace.menuHidden.contains) ?? false)
    }

    /// One menu item: `intent`'s title (or `title`) on its catalog spec (`FlareWorkspace.menuSpec(for:)`, command-state
    /// CS-12), acting through the focused window and disabled with its reason while it can't act.
    private func item(_ intent: FlareIntent, title: String? = nil, key: KeyboardShortcut? = nil) -> MenuCommand {
        MenuCommand(FlareWorkspace.menuSpec(for: intent), on: menu.help(intent), title: title ?? intent.title, shortcut: key) {
            menu.perform(intent)
        }
    }
}
