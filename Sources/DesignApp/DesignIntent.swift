// DesignIntent.swift: everything a person can ask Design's window to do, as one
// value. Every control in the toolbar, palette, canvas, sidebar, inspector and
// menus sends one of these to DesignWindow.perform, which calls the matching
// DesignWorkspace method or opens a panel. Also the intent of each toolbar
// command (DesignToolbarItem), the palette look of DesignTool (title, symbol,
// one-key shortcut, pointer) and the small bridges between DesignModel's plain
// types and SwiftUI's. The cases are the contract the view files build on.
import AppKit
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

enum DesignIntent {
    case newFile, open, save, saveAs, export
    case undo, redo
    case tool(DesignTool)
    case drag(CGPoint, CGPoint, DesignModifiers)
    case endDrag
    case nudge(DesignDirection, shift: Bool)
    case deleteSelection, deselect
    /// Edit > Enter Group or Return; Edit > Exit Group or Escape inside a group (select.enter-group, select.exit-group).
    case enterGroup, exitGroup
    case select(String)
    /// Shift-click: add the layer to the selection or take it out.
    case toggleSelect(String)
    case setExpanded(String, Bool)
    case addPage, deletePage
    case setFrame(String, x: Double, y: Double, width: Double, height: Double)
    case setFill(String, DesignColor)
    /// A Fill section gesture (type switch, stop, angle), run as its kernel fill command (`runFill`).
    case fill(GradientIntent)
    /// A turn or flip from the inspector or the Object menu, run as its kernel command (`runTransform`).
    case transform(TransformIntent)
    /// A change from the Shape tool's options in the inspector, applied to the tool's next spec (`runShape`).
    case shape(ShapeIntent)
    case align(DesignAlignEdge)
    case endEditRun
    case setHidden(String, Bool), setLocked(String, Bool)
    case toggleFlag(String, DesignLayerFlag)
    case editText(String)
    case textDraft(String), commitText, cancelText
    case zoomIn, zoomOut, fit
    /// Playback on the one clock (DesignWindow+Playback.swift): shown state, never an edit.
    case play, pause, stop, playPause
    /// A selection command (DesignCommand): duplicate, group, ungroup, delete, nudge, align,
    /// distribute or arrange; a refusal's help goes to the status line.
    case command(DesignCommand)
    case copy, cut, paste, selectAll
    /// Edit > Copy As (one representation) and Paste as Image (an image or SVG only), clipboard-interop CB-6.
    case copyAs(CopyAsFormat), pasteAsImage
    /// View > Zoom to Selection: the zoom that fits the selection, and the rect to show.
    case zoomToSelection
    /// A Layers panel drag: the layer, its new parent (nil: the page's top level) and index.
    case moveLayer(String, parent: String?, index: Int)
    /// One inspector row on every selected layer.
    case setStyle(DesignStyleChange)
    case renamePage(String, String)
    /// A Layers row's rename: the layer and its new name, one "Rename Layer" step.
    case renameLayer(String, String)
    /// The inspector's Width or Height committed: the selected page's size, one "Change Page Size" step.
    case setPageSize(width: Double, height: Double)
    /// An Eyedropper click: the colour at the page point onto the selection's stroke (Option) or fill, one step.
    case pick(DesignPoint, toStroke: Bool)
    /// The inspector's Eyedropper options: the square it reads, and whether a plain click picks the stroke.
    case sampleSize(SampleSize), sampleTarget(toStroke: Bool)
    /// A live command ran on a copy of the file (EM-4): the window becomes it.
    case adoptLive(DesignWorkspace)
}

/// Where a view sends its intents.
typealias DesignPerform = @MainActor (DesignIntent) -> Void

extension DesignToolbarItem {
    /// What the toolbar command asks the window to do; nil for History, which toggles the
    /// window's own panel (DesignHistoryArea) rather than asking the workspace.
    var intent: DesignIntent? {
        switch self {
        case .newFile: .newFile
        case .open: .open
        case .save: .save
        case .undo: .undo
        case .redo: .redo
        case .history: nil
        case .zoomOut: .zoomOut
        case .fit: .fit
        case .zoomIn: .zoomIn
        }
    }
}

extension DesignTool: PaletteTool {
    public var title: String {
        switch self {
        case .move: "Move"
        case .frame: "Frame"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .shape: "Shape"
        case .text: "Text"
        case .pen: "Pen"
        case .eyedropper: "Eyedropper"
        }
    }

    public var systemImage: String {
        switch self {
        case .move: "cursorarrow"
        case .frame: "number"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .shape: "star"
        case .text: "textformat"
        case .pen: "pencil.tip"
        case .eyedropper: "eyedropper"
        }
    }

    public var shortcut: Character? {
        switch self {
        case .move: "v"
        case .frame: "f"
        case .rectangle: "r"
        case .ellipse: "o"
        case .shape: "u"
        case .text: "t"
        case .pen: "p"
        case .eyedropper: "i"
        }
    }

    /// The pointer over the canvas while this tool is active.
    var pointer: PointerStyle {
        switch self {
        case .move, .pen, .eyedropper: .default
        case .frame, .rectangle, .ellipse, .shape: .rectSelection
        case .text: .horizontalText
        }
    }
}

extension DesignColor {
    /// Design's one bridge to SuiteUI's HexColor: the same 8-bit sRGB channels.
    init(hex: HexColor) { self.init(hex.red, hex.green, hex.blue) }

    /// The color as SuiteUI's color rows and parser speak it.
    var hex: HexColor { HexColor(red, green, blue) }

    /// The color as SwiftUI draws it, through the hex bridge.
    var color: Color { hex.color }
}

extension DesignModifiers {
    /// The modifier keys held right now and View > Snap to Layers, for the drag the pointer is making; ⌘ also
    /// picks the deepest layer (`.deep`) and the second press of a double-click enters the picked group (`.enter`).
    static var current: DesignModifiers {
        var modifiers = make(flags: NSEvent.modifierFlags, defaults: .standard)
        if KeyModifiers(flags: NSEvent.modifierFlags).contains(.command) { modifiers.insert(.deep) }
        // clickCount is only read on a mouse-down: AppKit raises on a non-mouse event.
        if let event = NSApp.currentEvent, event.type == .leftMouseDown, event.clickCount >= 2 { modifiers.insert(.enter) }
        return modifiers
    }

    /// Shift and Option as held; `.noSnap` when ⌘ is held or Snap to Layers is off in `defaults` (snapping SN-8).
    /// The flags are read through SuiteUI's `KeyModifiers(flags:)` (AC-tools).
    static func make(flags: NSEvent.ModifierFlags, defaults: UserDefaults) -> DesignModifiers {
        let held = KeyModifiers(flags: flags)
        return DesignModifiers(
            shift: held.contains(.shift), option: held.contains(.option),
            command: held.contains(.command), snapToLayers: snapsToLayers(in: defaults))
    }

    /// View > Snap to Layers as `defaults` holds it; a missing value reads as on.
    static func snapsToLayers(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: DesignSnapSettings.defaultsKey) as? Bool ?? true
    }
}

extension DesignPoint {
    init(_ point: CGPoint) {
        self.init(x: Double(point.x), y: Double(point.y))
    }
}

extension DesignRect {
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
