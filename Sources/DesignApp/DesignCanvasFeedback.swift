// DesignCanvasFeedback.swift: the canvas's tool feedback (design-window DW-d): the
// pointer CanvasViewport shows, the handler for where the pointer is over the
// artboard, and the marks drawn on top of the overlay. Each pointer sample asks the
// Model's `hover(at:modifiers:)` (DesignCanvasHints) and keeps the answer in
// DesignCanvasHover, an observed store outside the Model; the answer is written only
// when it changes, so 120 samples inside one layer re-run the canvas at most once and
// the editor never. The pointer is the one the answer names: a frame-resize pointer
// per handle, the open hand over a layer a Move drag would move, the drag-copy pointer
// with Option, the I-beam for the Text tool, else the tool's own. The hover outline is
// a 1 pt accent frame round the layer a click would pick, identified
// `design.canvas.hover` with the pointer's name as its value; it is asked again of the
// Model when drawn, so it follows the layer and never shows while a gesture runs. The
// size badge comes later (D0-9d). It reads the model and never writes it.
import AppKit
import DesignModel
import SuiteUI
import SwiftUI

struct DesignCanvasFeedback: View {
    let model: DesignWorkspace
    let zoom: Double
    /// The store the canvas this feedback belongs to reads and writes.
    let store = DesignCanvasHover.current

    /// The pointer over the canvas: the one the last hover answer names, or the tool's own.
    var pointer: PointerStyle {
        #if DEBUG
        if store.belongs(to: model) { store.canvasReads += 1 }
        #endif
        return DesignCanvasPointer(store.hint(for: model), tool: model.tool).style
    }

    /// Called with the pointer's place on the artboard, nil when it leaves.
    var onPointer: (@MainActor (CGPoint?) -> Void)? {
        let (store, model) = (store, model)
        return { point in store.record(point.map(DesignPoint.init), modifiers: .current, on: model) }
    }

    var body: some View {
        // The observed answer says whether to draw; the same question asked again of today's Model
        // says what: no outline mid-gesture, and the layer's frame as it is now.
        let now = model.hover(at: store.point, modifiers: store.modifiers)
        if store.hint(for: model) != nil, now.nodeID != nil, let rect = now.outline {
            DesignHoverMark(rect: rect, zoom: zoom, name: now.pointer.name)
        }
    }
}

/// The last hover answer of the canvas the pointer is over. Only `answer` and `key` are observed;
/// the point and modifiers it came from are kept for the outline to ask again.
@MainActor @Observable final class DesignCanvasHover {
    /// The app's one store: one pointer is over at most one canvas.
    static let shared = DesignCanvasHover()
    /// A store the snapshots bind around a render, so they never share the app's.
    @TaskLocal static var bound: DesignCanvasHover?
    static var current: DesignCanvasHover { bound ?? shared }

    private(set) var answer: DesignHover?
    /// The document and page the answer is for.
    private(set) var key: Key?
    @ObservationIgnored private(set) var point: DesignPoint?
    @ObservationIgnored private(set) var modifiers: DesignModifiers = []
    #if DEBUG
    /// How many times a canvas showing this store's page read its pointer: once per canvas body.
    @ObservationIgnored var canvasReads = 0
    #endif

    struct Key: Equatable {
        let document: URL?
        let page: String?
        init(_ model: DesignWorkspace) { (document, page) = (model.documentURL, model.selectedPageID) }
    }

    /// Asks `model` what a click at `point` would do and keeps the answer; writes only on a change.
    func record(_ point: DesignPoint?, modifiers: DesignModifiers, on model: DesignWorkspace) {
        (self.point, self.modifiers) = (point, modifiers)
        let asked = model.hover(at: point, modifiers: modifiers)
        let next = asked.nodeID == nil && asked.outline == nil && asked.pointer == .tool ? nil : asked
        let place = Key(model)
        if key != place { key = place }
        if answer != next { answer = next }
    }

    func belongs(to model: DesignWorkspace) -> Bool { key == Key(model) }

    /// The answer for `model`'s page; nil for another canvas or when there is nothing to show.
    func hint(for model: DesignWorkspace) -> DesignHover? { belongs(to: model) ? answer : nil }
}

/// The pointer a hover answer names, as a value the tests compare (PointerStyle is not Equatable).
enum DesignCanvasPointer: Equatable {
    case tool(DesignTool)
    case resize(FrameResizePosition)
    case move
    case copy
    case text

    init(_ hint: DesignHover?, tool: DesignTool) {
        switch hint?.pointer {
        case .resize(let handle)?: self = .resize(handle.position)
        case .move?: self = .move
        case .copy?: self = .copy
        case .text?: self = .text
        case .tool?, nil: self = .tool(tool)
        }
    }

    var style: PointerStyle {
        switch self {
        case .tool(let tool): tool.pointer
        case .resize(let position): .frameResize(position: position)
        case .move: .grabIdle
        case .text: .horizontalText
        case .copy:
            // The system's drag-copy pointer; its hot spot as a unit point of its image.
            let cursor = NSCursor.dragCopy
            let size = cursor.image.size
            guard size.width > 0, size.height > 0 else { return .default }
            return .image(
                Image(nsImage: cursor.image),
                hotSpot: UnitPoint(x: cursor.hotSpot.x / size.width, y: cursor.hotSpot.y / size.height))
        }
    }
}

extension DesignHandle {
    /// The edge or corner of the frame this handle resizes from.
    var position: FrameResizePosition {
        switch self {
        case .topLeft: .topLeading
        case .top: .top
        case .topRight: .topTrailing
        case .right: .trailing
        case .bottomRight: .bottomTrailing
        case .bottom: .bottom
        case .bottomLeft: .bottomLeading
        case .left: .leading
        }
    }
}

/// The hover outline: a 1 pt accent frame round `rect` (page points) at `zoom`, one size at any
/// zoom, identified `design.canvas.hover` with the pointer's name as its value. Takes no clicks.
private struct DesignHoverMark: View {
    let rect: DesignRect
    let zoom: Double
    let name: String

    var body: some View {
        let scale = usable(zoom)
        let box = rect.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale)).standardized
        ZStack(alignment: .topLeading) {
            Path(box).stroke(SuiteColor.accent, lineWidth: 1)
            Color.clear
                .frame(width: box.width, height: box.height)
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: "Hover"))
                .accessibilityValue(Text(verbatim: name))
                .accessibilityIdentifier(DesignControlID.canvasHover)
                .accessibilityAddTraits(.isImage)
                .padding(.leading, box.minX)
                .padding(.top, box.minY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
