// FlareCommands.swift: Flare's menu bar, docs/blueprints/flare.md section
// 3.4. Every item is one FlareIntent: it acts through the focused window's
// `perform` and is disabled, never hidden, while that window's `help` gives a
// reason (shown as the item's help). The keys of section 3.4 (Space, the
// arrows, Home, End, K, ⌥K and the ⌘ keys) live only here; no view binds them
// again. Return and Escape stay the stage's (toolKey); Object > Finish Path is
// Return's item for the mouse, with no key of its own. Undo and Redo are
// titled by the step, as in "Undo Set Keyframe Easing". File > Open Sample
// lists Bounce, Character, Button and Keyed Ball, the keyed document the
// easing journey starts from; Open Recent lists the window's recent files,
// then Clear Menu. The focused window publishes a FlareMenu as a focused
// scene value (FlareWindow.swift); with none focused every item disables.
import FlareModel
import SwiftUI

/// What the focused Flare window's menus can do now.
struct FlareMenu {
    var perform: @MainActor (FlareIntent) -> Void = { _ in }
    var help: @MainActor (FlareIntent) -> String? = { _ in "Open a Flare window first." }
    var undoTitle = "Undo"
    var redoTitle = "Redo"
    var recent: [String] = []
    var loops = false

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
        CommandGroup(replacing: .newItem) {
            item(.file(.new), key: KeyboardShortcut("n"))
            item(.file(.open), key: KeyboardShortcut("o"))
            Menu("Open Recent") {
                ForEach(menu.recent, id: \.self) { path in
                    item(.file(.openRecent(path: path)), title: URL(fileURLWithPath: path).lastPathComponent)
                }
                Divider()
                item(.file(.clearRecent))
            }
            Menu("Open Sample") {
                ForEach(FlareMenu.samples, id: \.name) { sample in
                    item(.file(.openSample(name: sample.name)), title: sample.title)
                }
            }
        }
        CommandGroup(replacing: .saveItem) {
            item(.file(.save), key: KeyboardShortcut("s"))
            item(.file(.saveAs), key: KeyboardShortcut("s", modifiers: [.command, .shift]))
            item(.export(.showSheet), key: KeyboardShortcut("e", modifiers: [.command, .shift]))
            item(.file(.close), key: KeyboardShortcut("w"))
        }
        CommandGroup(replacing: .importExport) {}
        CommandGroup(replacing: .printItem) {}
        CommandGroup(replacing: .undoRedo) {
            item(.edit(.undo), title: menu.undoTitle, key: KeyboardShortcut("z"))
            item(.edit(.redo), title: menu.redoTitle, key: KeyboardShortcut("z", modifiers: [.command, .shift]))
        }
        CommandGroup(replacing: .pasteboard) {
            item(.edit(.cut), key: KeyboardShortcut("x"))
            item(.edit(.copy), key: KeyboardShortcut("c"))
            item(.edit(.paste), key: KeyboardShortcut("v"))
            item(.edit(.duplicate), key: KeyboardShortcut("d"))
            item(.edit(.delete), key: KeyboardShortcut(.delete, modifiers: []))
            item(.edit(.selectAll), key: KeyboardShortcut("a"))
            item(.edit(.deselect), key: KeyboardShortcut("a", modifiers: [.command, .shift]))
        }
        CommandGroup(before: .toolbar) {
            item(.view(.zoomIn), key: KeyboardShortcut("+"))
            item(.view(.zoomOut), key: KeyboardShortcut("-"))
            item(.view(.fit), key: KeyboardShortcut("0"))
            item(.view(.actualSize), key: KeyboardShortcut("1"))
            item(.view(.toggleOnion), key: KeyboardShortcut("o", modifiers: [.command, .option]))
            item(.view(.toggleMotionPath))
            item(.view(.toggleRulers), key: KeyboardShortcut("r"))
            item(.view(.toggleGuides), key: KeyboardShortcut(";"))
            item(.view(.clearGuides))
            Divider()
        }
        CommandMenu("Object") {
            item(.library(.convertToSymbol(name: "")), key: KeyboardShortcut("k", modifiers: [.command, .option]))
            item(.library(.edit(id: "")))
            item(.library(.exitSymbol))
            Divider()
            item(.edit(.bringForward), key: KeyboardShortcut("]"))
            item(.edit(.sendBackward), key: KeyboardShortcut("["))
            Divider()
            // No key: Return stays the stage's (toolKey), so a text field's Return is never taken.
            item(.tools(.finishPath))
        }
        CommandMenu("Animate") { animate }
        CommandGroup(before: .windowSize) {
            item(.interactions(.toggleEditor), key: KeyboardShortcut("m", modifiers: [.command, .shift]))
            Divider()
        }
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
        Divider()
        item(.assist(.showPopover), key: KeyboardShortcut("a", modifiers: [.command, .option]))
    }

    /// One menu item: `intent`'s title (or `title`), acting through the
    /// focused window and disabled with its reason while it can't act.
    private func item(_ intent: FlareIntent, title: String? = nil, key: KeyboardShortcut? = nil) -> some View {
        let reason = menu.help(intent)
        return Button(title ?? intent.title) { menu.perform(intent) }
            .keyboardShortcut(key)
            .disabled(reason != nil)
            .help(reason ?? "")
    }
}
