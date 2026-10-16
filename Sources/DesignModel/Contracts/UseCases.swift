// Contracts/UseCases.swift: one protocol per Design use case. Reads take the
// page; writes take the page (and a mint when they add nodes) and return a
// DesignEdit or throw DesignRefusal. Each write's comment names its undo case:
// **single "Name"** (one step), or **coalescing "key"** (a run with that key is
// one step). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: Tier 1

/// Marquee: which layers a dragged rectangle on empty canvas selects.
public protocol MarqueeSelecting: Sendable {
    /// The visible, unlocked layers `rect` touches, in paint order. Candidates are the children of
    /// `parentID` (the frame the marquee started in), or the page's top-level layers when nil. A
    /// hidden or locked layer, or one inside a hidden or locked layer, is never picked.
    func layers(touching rect: DesignRect, in parentID: String?, on page: DesignPage) -> [String]
}

/// Move, resize, nudge and delete for one or more selected layers.
public protocol SelectionTransforming: Sendable {
    func transformHelp(_ ids: [String], on page: DesignPage) -> String?
    /// Coalescing "move" (`runKey`): every selected layer with its subtree, by `delta` from the gesture start.
    func move(_ ids: [String], by delta: DesignPoint, on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "resize": the selection's box by `handle`; each layer scales inside the box.
    func resize(_ ids: [String], handle: DesignHandle, by delta: DesignPoint, modifiers: DesignModifiers,
                on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "nudge": 1 pt, or 10 pt with `large`.
    func nudge(_ ids: [String], _ direction: DesignDirection, large: Bool, on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Single "Delete" (one layer: "Delete <Kind>").
    func delete(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
}

/// Align to the selection's bounds (or the enclosing frame or page for one layer), and distribute.
public protocol LayerAligning: Sendable {
    func alignHelp(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) -> String?
    /// Single, named `edge.title`. Locked layers count toward the bounds but don't move.
    func align(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    func distributeHelp(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) -> String?
    /// Single, named `axis.title`. Needs three or more layers (`.tooFewToDistribute`); the outer two stay.
    func distribute(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
}

/// Duplicate (Command-D) and the copy an Option-drag moves.
public protocol LayerDuplicating: Sendable {
    func duplicateHelp(_ ids: [String], on page: DesignPage) -> String?
    /// Single "Duplicate". Each copy sits right above its original in the same parent, moved by
    /// `offset` (10, 10 for Command-D; zero for Option-drag), unlocked; the copies are the selection.
    func duplicate(_ ids: [String], offset: DesignPoint, on page: DesignPage,
                   mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
    /// `node` and its subtree with fresh ids from `mint`; everything else equal. The clipboard reuses it.
    func copySubtree(_ node: DesignNode, mint: inout DesignIDMint) -> DesignNode
}

/// Group (Command-G) and Ungroup (Shift-Command-G).
public protocol LayerGrouping: Sendable {
    func groupHelp(_ ids: [String], on page: DesignPage) -> String?
    /// Single "Group". The group's frame is the union; it takes the topmost layer's place; nothing moves.
    func group(_ ids: [String], on page: DesignPage, mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
    func ungroupHelp(_ ids: [String], on page: DesignPage) -> String?
    /// Single "Ungroup". Each selected group's children take its place, in order; the children are the selection.
    func ungroup(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
}

/// Cut, Copy and Paste of layers through the system pasteboard (the app moves the bytes).
public protocol LayerClipboard: Sendable {
    /// The pasteboard type the app reads and writes.
    var pasteboardType: String { get }
    func copyHelp(_ ids: [String], on page: DesignPage) -> String?
    /// The selected layers, children included, and the id of the parent they came from, as bytes.
    func encode(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> Data
    /// Why Paste is off for these pasteboard bytes (nil: the pasteboard holds none of our type).
    func pasteHelp(_ data: Data?) -> String?
    /// Single "Paste". Fresh ids. Into `parentID` when the caller passes one (a selected frame);
    /// else into the parent the copies came from when it is on `page`; else the top level (#415).
    /// Offset by (10, 10) when a copy would land exactly on a layer with the same name and frame.
    func paste(_ data: Data, into parentID: String?, on page: DesignPage,
               mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
}

/// Stacking order and nesting from the Layers panel and Object > Arrange.
public protocol LayerOrdering: Sendable {
    func moveHelp(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) -> String?
    /// Single "Move Layer". `index` counts the new parent's children back to front, after removal.
    func move(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    func arrangeHelp(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) -> String?
    /// Single, named `step.title`. Within each layer's own parent.
    func arrange(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
}

/// The inspector's rows for one or several layers: X, Y, W, H, fill, corner radius, opacity,
/// stroke and text style. With several layers a value goes to each of them (a "Mixed" row too).
public protocol StyleEditing: Sendable {
    func styleHelp(_ property: DesignStyleProperty, _ ids: [String], on page: DesignPage) -> String?
    /// Coalescing "frame": X and Y move each layer with its subtree; W and H at least 1.
    func setFrame(_ field: DesignFrameField, to value: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "fill".
    func setFill(_ color: DesignColor, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "radius". Clamped to 0...half the shorter side. Rectangles and frames take it; in a
    /// mixed selection the others are skipped, and a selection with none of them throws `.noCorners`.
    func setCornerRadius(_ radius: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "opacity". Clamped to 0...1. The layer's opacity: it fades the fill, stroke and text,
    /// and for a frame or group everything inside it.
    func setOpacity(_ opacity: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "stroke". nil removes the stroke; width clamped to 0...1000.
    func setStroke(_ stroke: DesignStroke?, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
    /// Coalescing "text-style". Size clamped to 1...1000, weight to 100...900. Text layers take it;
    /// others in a mixed selection are skipped, and a selection with none throws `.notText`.
    func setTextStyle(_ style: DesignTextStyle, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit
}

/// What View > Zoom to Selection shows.
public protocol ViewFraming: Sendable {
    /// "Select a layer first." with nothing visible selected; nil exactly when `rectToShow` is not nil.
    func framingHelp(_ ids: [String], on page: DesignPage) -> String?
    /// The union of the visible selected layers' frames; nil with none (the command is then off).
    func rectToShow(_ ids: [String], on page: DesignPage) -> DesignRect?
}

/// The file codec behind Open, Save and Save As.
public protocol DocumentFiling: Sendable {
    /// Same document, same bytes (sorted keys). Refuses what `decode` would refuse.
    func encode(_ document: DesignDocument) throws(DesignFileError) -> Data
    /// All or nothing: a refused file throws and the caller keeps what it had.
    func decode(_ data: Data) throws(DesignFileError) -> DesignDocument
}

/// What a file holds. `components` and `variables` stay empty until wave 2 (D2-1).
public struct DesignDocument: Sendable, Equatable {
    public var pages: [DesignPage]
    public var components: [DesignComponent]
    public var variables: [DesignVariable]

    public init(pages: [DesignPage], components: [DesignComponent] = [], variables: [DesignVariable] = []) {
        (self.pages, self.components, self.variables) = (pages, components, variables)
    }
}

// MARK: Tier 2

/// File > Export: what to write and the SVG text (PNG and PDF are rendered by DesignApp).
public protocol ExportPlanning: Sendable {
    func exportHelp(_ ids: [String], on page: DesignPage) -> String?
    /// The selected layers, or every top-level frame when `ids` is empty; names made unique against `existing`.
    func plan(_ ids: [String], on page: DesignPage, format: DesignExportFormat, scale: Int,
              existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem]
    /// The layer as an SVG document: viewBox in its points, hidden layers left out, frames clip.
    func svg(for id: String, on page: DesignPage) throws(DesignRefusal) -> String
}

/// The Pen tool: click for corners, drag for smooth points, click the first anchor to close.
public protocol PathDrawing: Sendable {
    /// The draft after a press at `point`; closes it when `point` is within `tolerance` of the first anchor.
    func press(at point: DesignPoint, draft: DesignPath?, tolerance: Double) -> DesignPath
    /// The draft's last anchor made smooth, its out handle at `point` and its in handle mirrored.
    func dragHandle(to point: DesignPoint, draft: DesignPath) -> DesignPath
    /// The tight bounds of the path's curves (not of its handles).
    func bounds(of path: DesignPath) -> DesignRect?
    /// Single "Add Path". Refused with fewer than two anchors.
    func commit(_ draft: DesignPath, into parentID: String?, on page: DesignPage,
                mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
}

/// Components and instances.
public protocol ComponentLibrary: Sendable {
    func createHelp(_ ids: [String], on page: DesignPage) -> String?
    /// Single "Create Component": the selected frame becomes the component and its first instance.
    func create(from id: String, on page: DesignPage, library: [DesignComponent],
                mint: inout DesignIDMint) throws(DesignRefusal) -> (edit: DesignEdit, library: [DesignComponent])
    /// Single "Insert <name>": an instance centered on `center`, selected.
    func insert(_ componentID: String, centeredOn center: DesignPoint, on page: DesignPage,
                library: [DesignComponent], mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
    /// What an instance draws: the component's nodes moved to the instance's frame; nil when it is missing.
    func resolve(_ instance: DesignNode, library: [DesignComponent]) -> [DesignNode]?
}

/// Variables with a light and a dark value.
public protocol VariableEditing: Sendable {
    /// Single "Add Variable". Refused when the name is empty or taken.
    func add(named name: String, value: DesignVariableValue, to variables: [DesignVariable],
             id: String) throws(DesignRefusal) -> [DesignVariable]
    /// Single "Rename Variable".
    func rename(_ id: String, to name: String, in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable]
    /// Single "Delete Variable". Layers bound to it keep their own fill.
    func remove(_ id: String, from variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable]
    /// Coalescing "variable-<id>-<mode>".
    func set(_ id: String, _ mode: DesignMode, to value: DesignVariableValue,
             in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable]
    func resolve(_ id: String, in mode: DesignMode, variables: [DesignVariable]) -> DesignVariableValue?
    /// Single "Bind Fill" (nil: "Unbind Fill"). Binds each layer's fill to a color variable.
    func bind(_ variableID: String?, _ ids: [String], on page: DesignPage,
              variables: [DesignVariable]) throws(DesignRefusal) -> DesignEdit
}
