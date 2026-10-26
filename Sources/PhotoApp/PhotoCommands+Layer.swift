// PhotoCommands+Layer.swift: Photo's Layer menu: New, New Adjustment Layer
// (a submenu of the kinds the workspace offers, each disabled with its reason
// as its help when it can't run; Blur is never one; the submenu itself is
// disabled with that reason when no kind can be added), Delete; Duplicate Layer
// (Command-J), Merge Down (Command-E) and Flatten Image (no shortcut), each
// disabled with the workspace's reason as its help when it can't run;
// Rename…, Show/Hide, Bring Forward, Send Backward, Select Layer Above and
// Below; Layer Style… (the style panel at Drop Shadow), Copy, Paste and Clear
// Layer Style, each disabled with its reason. The items are a view, PhotoLayerMenu, so the snapshot tests can draw
// them; shortcuts and symbols are tables the tests read, and `symbol(_:)` is
// shared with the Layers panel's bar and row menus (PhotoLayerList).
import AppKit
import PhotoModel
import SuiteImaging
import SuiteUI
import SwiftUI

extension PhotoCommands {
    var layerMenu: some Commands {
        CommandMenu("Layer") {
            PhotoLayerMenu(menu: menu)
        }
    }
}

/// The Layer menu's items, a view so the snapshot tests can draw them.
struct PhotoLayerMenu: View {
    let menu: PhotoMenu

    var body: some View {
        menu.item("layer.new", systemImage: Self.symbol("layer.new"), shortcut: KeyboardShortcut("n", modifiers: [.command, .shift])) {
            menu.perform(.addLayer)
        }
        adjustmentLayerMenu
        menu.item("layer.delete", systemImage: Self.symbol("layer.delete")) { menu.perform(.deleteLayer) }
        Divider()
        item("layer.duplicate", .duplicateLayer)
        item("layer.merge-down", .mergeDown)
        item("layer.flatten", .flattenImage)
        Divider()
        menu.item("layer.rename", systemImage: Self.symbol("layer.rename")) { menu.perform(.renameLayer) }
        menu.item("layer.toggle-visibility", systemImage: Self.symbol("layer.toggle-visibility", visibility: menu.visibilityTitle)) {
            if let selected = menu.selectedLayer { menu.perform(.toggleVisibility(selected)) }
        }
        Divider()
        menu.item("layer.bring-forward", systemImage: Self.symbol("layer.bring-forward"), shortcut: KeyboardShortcut("]")) {
            menu.perform(.bringForward)
        }
        menu.item("layer.send-backward", systemImage: Self.symbol("layer.send-backward"), shortcut: KeyboardShortcut("[")) {
            menu.perform(.sendBackward)
        }
        menu.item("layer.select-above", systemImage: "arrow.up", shortcut: KeyboardShortcut("]", modifiers: [.command, .option])) {
            menu.perform(.selectLayerAbove)
        }
        menu.item("layer.select-below", systemImage: "arrow.down", shortcut: KeyboardShortcut("[", modifiers: [.command, .option])) {
            menu.perform(.selectLayerBelow)
        }
        Divider()
        styleItems
    }

    /// Layer Style… (the panel at Drop Shadow), Copy, Paste and Clear Layer Style; Paste reads the style pasteboard.
    @ViewBuilder private var styleItems: some View {
        menu.item("style.panel", systemImage: Self.symbol("style.panel")) { menu.perform(.style(.panel(.show(.dropShadow)))) }
        menu.item("style.copy", systemImage: Self.symbol("style.copy")) { menu.perform(.style(.copy)) }
        menu.item("style.paste", systemImage: Self.symbol("style.paste"), in: pasteState) { menu.perform(.style(.paste)) }
        menu.item("style.clear", systemImage: Self.symbol("style.clear")) { menu.perform(.style(.clear)) }
    }

    /// The menu's state with whether the style pasteboard holds a style, which Paste Layer Style reads.
    private var pasteState: PhotoMenuState {
        var state = menu.state()
        state.pasteboardHasStyle = LayerStylePasteboard.read() != nil
        return state
    }

    /// Command-J and Command-E; Flatten Image has none (QB-F4).
    static func shortcut(_ intent: EditIntent) -> KeyboardShortcut? {
        switch intent {
        case .duplicateLayer: KeyboardShortcut("j")
        case .mergeDown: KeyboardShortcut("e")
        case .cut, .copy, .paste, .flattenImage: nil
        }
    }

    /// The three layer commands' symbols. Merge Down's reads as two layers
    /// becoming one, not as a save (the square.and.arrow family).
    nonisolated static func systemImage(_ intent: EditIntent) -> String {
        switch intent {
        case .duplicateLayer: "plus.square.on.square"
        case .mergeDown: "rectangle.compress.vertical"
        case .flattenImage: "square.stack.3d.down.right"
        case .cut: PhotoEditItem.cut.systemImage
        case .copy: PhotoEditItem.copy.systemImage
        case .paste: PhotoEditItem.paste.systemImage
        }
    }

    /// A layer command's symbol by catalog id, for the Layer menu and the Layers panel alike;
    /// Show/Hide follows the title the menu gives it (`visibility`).
    nonisolated static func symbol(_ id: String, visibility: String = "Hide Layer") -> String {
        switch id {
        case "layer.new": "plus"
        case "layer.delete": "trash"
        case "layer.rename": "pencil"
        case "layer.toggle-visibility": visibility == "Show Layer" ? "eye" : "eye.slash"
        case "layer.bring-forward": "square.2.layers.3d.top.filled"
        case "layer.send-backward": "square.2.layers.3d.bottom.filled"
        case "layer.duplicate": systemImage(.duplicateLayer)
        case "layer.merge-down": systemImage(.mergeDown)
        case "layer.flatten": systemImage(.flattenImage)
        case "style.panel": "fx"
        case "style.copy": "doc.on.doc"
        case "style.paste": "doc.on.clipboard"
        case "style.clear": "xmark.circle"
        default: "square.stack"
        }
    }

    /// New Adjustment Layer: one item per kind, disabled with its reason as its help.
    private var adjustmentLayerMenu: some View {
        let help = menu.addAdjustmentLayerHelp
        return Menu("New Adjustment Layer", systemImage: "slider.horizontal.3") {
            ForEach(menu.adjustmentLayerKinds, id: \.self) { kind in
                menu.item("layer.new-adjustment", title: kind.title) { menu.perform(.adjustmentLayer(.add(kind))) }
            }
        }
        .disabled(menu.adjustmentMenuDisabled)
        .help(help ?? "New Adjustment Layer")
    }

    /// A layer command from its catalog spec, disabled with its reason as its help when it can't run.
    private func item(_ id: String, _ intent: EditIntent) -> MenuCommand {
        menu.item(id, systemImage: Self.systemImage(intent), shortcut: Self.shortcut(intent)) { menu.perform(.edit(intent)) }
    }
}

extension PhotoMenu {
    /// New Adjustment Layer's submenu is itself disabled when none of its
    /// kinds can be added, so it reads dimmed rather than opening onto dead items.
    var adjustmentMenuDisabled: Bool {
        adjustmentLayerKinds.isEmpty || addAdjustmentLayerHelp != nil
    }
}

/// The layer commands as selectors, only so `PhotoMenu.textAction` covers
/// every edit; nothing implements them, as the Layer menu sends these to the
/// window directly.
@objc protocol PhotoLayerActions {
    func duplicateLayer(_ sender: Any?)
    func mergeDown(_ sender: Any?)
    func flattenImage(_ sender: Any?)
}
