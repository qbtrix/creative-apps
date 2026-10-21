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
// Model when drawn, so it follows the layer and never shows while a gesture runs. With
// the Text tool the same mark is dashed and is the box a click would place at the
// pointer (`placement`, observed by this body alone, so the canvas body never re-runs
// as it follows the pointer). The size badge (`design.canvas.badge`) is the Model's
// `selectionBadge` in a caption pill hung clear of the selection's bottom handle, one size
// at any zoom; `model` is the live copy mid-drag, so it reads the drag as it runs, and an
// open text edit's box is read at its draft's measured size (#3335). Under it, while the
// typed text draws too small to read, the Model's `textLegibilityHint` hangs in a second
// pill (`design.canvas.textHint`, #3336), a warning status pill (SuiteUI's StatusPillFace). The
// smart guides (DesignGuideOverlay, `design.canvas.guides`) draw the same copy's
// `snapGuides`. It reads the model and never writes it.
import AppKit
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct DesignCanvasFeedback: View {
    let model: DesignWorkspace
    let zoom: Double
    /// The store the canvas this feedback belongs to reads and writes.
    let store = DesignCanvasHover.current
    /// Where the Eyedropper's picks go (DesignSampleLoupe).
    var perform: DesignPerform = { _ in }

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
        if store.shows(model), let rect = now.mark {
            DesignHoverMark(rect: rect, zoom: zoom, name: now.pointer.name, dashed: now.placement != nil)
        }
        // An open text edit's box as its draft measures, so the badge grows with the typing (#3335).
        let draft = DesignTextOverlay.draftExtent(model)
        if let badge = model.selectionBadge(draft: draft), let anchor = model.selectionBadgeAnchor(draft: draft) {
            DesignSizeBadge(text: badge, anchor: anchor, zoom: zoom)
            if let hint = model.textLegibilityHint(zoom: zoom) {
                DesignSizeBadge(text: hint, anchor: anchor, zoom: zoom, hint: true)
            }
        }
        DesignGuideOverlay(guides: DesignGuidePin.guides ?? model.snapGuides, zoom: zoom)
        // The Eyedropper's loupe and clicks; only its own body reads the loupe as it follows the pointer.
        DesignSampleLoupe(model: model, zoom: zoom, perform: perform)
    }
}

/// The last hover answer of the canvas the pointer is over. Only `answer`, `placement` and `key` are
/// observed; the point and modifiers it came from are kept for the outline to ask again. `answer`
/// drops the Text tool's box (`steady`), which moves with the pointer: only the feedback body reads
/// `placement`, so the canvas body doesn't re-run per sample.
@MainActor @Observable final class DesignCanvasHover {
    /// The app's one store: one pointer is over at most one canvas.
    static let shared = DesignCanvasHover()
    /// A store the snapshots bind around a render, so they never share the app's.
    @TaskLocal static var bound: DesignCanvasHover?
    static var current: DesignCanvasHover { bound ?? shared }

    private(set) var answer: DesignHover?
    /// The box a Text click would place at the pointer; nil for any other answer.
    private(set) var placement: DesignRect?
    /// The document and page the answer is for.
    private(set) var key: Key?
    @ObservationIgnored private(set) var point: DesignPoint?
    @ObservationIgnored private(set) var modifiers: DesignModifiers = []
    /// The Eyedropper's loupe at the pointer (DesignSampleLoupe reads it); nil for any other tool.
    private(set) var loupe: DesignLoupe?
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
        let place = Key(model)
        if key != place { key = place }
        if placement != asked.placement { placement = asked.placement }
        if answer != asked.steady { answer = asked.steady }
        let shown = model.loupe(at: point, modifiers: modifiers)
        if loupe != shown { loupe = shown }
    }

    /// The loupe for `model`'s page, asked again of `model` at the kept pointer so a change to the inspector's
    /// sample size or Fill/Stroke choice shows at once; nil for another canvas.
    func loupe(for model: DesignWorkspace) -> DesignLoupe? {
        guard belongs(to: model), let seen = loupe else { return nil }
        return model.loupe(at: seen.point, modifiers: modifiers)
    }

    func belongs(to model: DesignWorkspace) -> Bool { key == Key(model) }

    /// Whether the hover mark draws on `model`'s canvas; reads `placement` so its reader follows the Text box.
    func shows(_ model: DesignWorkspace) -> Bool {
        let box = placement
        return belongs(to: model) && (box != nil || answer != nil)
    }

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
        case .tool(let tool): return tool.pointer
        case .resize(let position): return .frameResize(position: position)
        case .move: return .grabIdle
        case .text: return .horizontalText
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
/// zoom, dashed for the Text tool's box, identified `design.canvas.hover` with the pointer's name as
/// its value. Takes no clicks.
private struct DesignHoverMark: View {
    let rect: DesignRect
    let zoom: Double
    let name: String
    let dashed: Bool

    var body: some View {
        let scale = usable(zoom)
        let box = rect.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale)).standardized
        ZStack(alignment: .topLeading) {
            Path(box).stroke(SuiteColor.accent, style: StrokeStyle(lineWidth: 1, dash: dashed ? [SuiteSpacing.xs] : []))
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

/// The size badge: `text` in a caption pill, its top `SuiteSpacing.xs` under the bottom-middle
/// handle below `anchor` (page points) at `zoom`, one size at any zoom, identified `design.canvas.badge` with `text` as its label.
/// A `hint` (the text legibility hint, `design.canvas.textHint`) hangs one pill lower as a warning
/// status pill, its tint, color and triangle (design.md State colors), so it never reads as a
/// second selection fact in accent.
private struct DesignSizeBadge: View {
    let text: String
    let anchor: DesignPoint
    let zoom: Double
    var hint = false

    var body: some View {
        let scale = usable(zoom)
        let row: CGFloat = hint ? 1 : 0
        pill
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: text))
            .accessibilityIdentifier(hint ? "design.canvas.textHint" : DesignControlID.canvasBadge)
            .position(
                x: CGFloat(anchor.x * scale),
                y: CGFloat(anchor.y * scale) + SuiteSize.selectionHandle / 2 + SuiteSpacing.xs + SuiteSize.pill / 2
                    + row * (SuiteSize.pill + SuiteSpacing.xs))
            .allowsHitTesting(false)
    }

    @ViewBuilder private var pill: some View {
        if hint {
            StatusPillFace(.warning) { Text(verbatim: text) }
        } else {
            Text(verbatim: text)
                .font(SuiteFont.caption.monospacedDigit())
                .foregroundStyle(SuiteColor.overlayPaper)
                .padding(SuiteInset.pill)
                .frame(height: SuiteSize.pill)
                .background(Capsule().fill(SuiteColor.accentFill))
        }
    }
}
