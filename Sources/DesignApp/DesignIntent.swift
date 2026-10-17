// DesignIntent.swift: everything a person can ask Design's window to do, as one
// value. Every control in the toolbar, palette, canvas, sidebar, inspector and
// menus sends one of these to DesignWindow.perform, which calls the matching
// DesignWorkspace method or opens a panel. Also the intent of each toolbar
// command (DesignToolbarItem), the palette look of DesignTool (title, symbol,
// one-key shortcut, pointer) and the small bridges between DesignModel's plain
// types and SwiftUI's. The cases are the contract the view files build on.
import AppKit
import DesignModel
import SuiteUI
import SwiftUI

enum DesignIntent {
    case newFile, open, save, saveAs
    case undo, redo
    case tool(DesignTool)
    case drag(CGPoint, CGPoint, DesignModifiers)
    case endDrag
    case nudge(DesignDirection, shift: Bool)
    case deleteSelection, deselect
    case select(String)
    /// Shift-click: add the layer to the selection or take it out.
    case toggleSelect(String)
    case setExpanded(String, Bool)
    case addPage, deletePage
    case setFrame(String, x: Double, y: Double, width: Double, height: Double)
    case setFill(String, DesignColor)
    case align(DesignAlignEdge)
    case endEditRun
    case setHidden(String, Bool), setLocked(String, Bool)
    case toggleFlag(String, DesignLayerFlag)
    case editText(String)
    case textDraft(String), commitText, cancelText
    case zoomIn, zoomOut, fit
    /// A selection command (DesignCommand): duplicate, group, ungroup, delete, nudge, align,
    /// distribute or arrange; a refusal's help goes to the status line.
    case command(DesignCommand)
    case copy, cut, paste, selectAll
    /// View > Zoom to Selection: the zoom that fits the selection, and the rect to show.
    case zoomToSelection
    /// A Layers panel drag: the layer, its new parent (nil: the page's top level) and index.
    case moveLayer(String, parent: String?, index: Int)
    /// One inspector row on every selected layer.
    case setStyle(DesignStyleChange)
    case renamePage(String, String)
}

/// Where a view sends its intents.
typealias DesignPerform = @MainActor (DesignIntent) -> Void

extension DesignToolbarItem {
    /// What the toolbar command asks the window to do.
    var intent: DesignIntent {
        switch self {
        case .newFile: .newFile
        case .open: .open
        case .save: .save
        case .undo: .undo
        case .redo: .redo
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
        case .text: "Text"
        case .pen: "Pen"
        }
    }

    public var systemImage: String {
        switch self {
        case .move: "cursorarrow"
        case .frame: "number"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .text: "textformat"
        case .pen: "pencil.tip"
        }
    }

    public var shortcut: Character? {
        switch self {
        case .move: "v"
        case .frame: "f"
        case .rectangle: "r"
        case .ellipse: "o"
        case .text: "t"
        case .pen: "p"
        }
    }

    /// The pointer over the canvas while this tool is active.
    var pointer: PointerStyle {
        switch self {
        case .move, .pen: .default
        case .frame, .rectangle, .ellipse: .rectSelection
        case .text: .horizontalText
        }
    }
}

extension DesignColor {
    /// The color as SwiftUI draws it, through SuiteUI's hex bridge.
    var color: Color { HexColor(red, green, blue).color }
}

extension DesignModifiers {
    /// The modifier keys held right now, for the drag the pointer is making.
    static var current: DesignModifiers {
        let flags = NSEvent.modifierFlags
        var held: DesignModifiers = []
        if flags.contains(.shift) { held.insert(.shift) }
        if flags.contains(.option) { held.insert(.option) }
        return held
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
