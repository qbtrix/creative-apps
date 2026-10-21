// HaloShapeDraft.swift (shape-tools HS-3): the viewer drag's Model half. The
// shape a drag draws with the tool's options and its draft outline, one drag's
// gesture (one shape per release, Escape), and `drawShape`. Linux-safe.
import FlareCore
import SuiteKernel

/// The shape a viewer drag draws: the tool's spec in a box, composition pixels.
public struct HaloShapeDrawn: Sendable, Hashable {
    public let spec: ShapeSpec
    public let box: Rect

    /// `tool` dragged from `from` to `to` (Shift squares, Option grows from the centre); nil for a click.
    public init?(_ tool: ShapeSpec, from: HaloPoint, to: HaloPoint, modifiers: EditModifiers = []) {
        guard let dragged = ShapeRules.dragged(tool.kind, from: from, to: to, modifiers: modifiers) else { return nil }
        var spec = tool
        (spec.start, spec.end) = (dragged.spec.start, dragged.spec.end)
        (self.spec, self.box) = (spec, dragged.box)
    }

    /// The new layer's name: its kind ("Star").
    public var name: String { spec.kind.rawValue.prefix(1).uppercased() + spec.kind.rawValue.dropFirst() }

    /// The path as polylines in composition pixels; empty when the rules refuse the spec.
    public var outline: [[HaloPoint]] { (try? ShapeRules.path(spec, in: box).flattened(tolerance: 0.5)) ?? [] }
}

/// One viewer drag with the shape tool: its draft, its one release, Escape.
public struct HaloShapeGesture: Sendable, Hashable {
    public private(set) var isDragging = false
    /// What the release would draw now; nil before the drag moves or after Escape.
    public private(set) var draft: HaloShapeDrawn?
    /// Whether Escape dropped this press; its later samples and release draw nothing.
    public private(set) var cancelled = false

    public init() {}

    public mutating func drag(_ tool: ShapeSpec, from: HaloPoint, to: HaloPoint, modifiers: EditModifiers = []) {
        isDragging = true
        guard !cancelled else { return }
        draft = HaloShapeDrawn(tool, from: from, to: to, modifiers: modifiers)
    }

    /// The shape to draw, once per press; nil for a click or a cancelled press.
    public mutating func release() -> HaloShapeDrawn? {
        defer { self = HaloShapeGesture() }
        return cancelled ? nil : draft
    }

    /// True when it dropped a drag in progress; false with none, so the viewer turns the tool off.
    public mutating func escape() -> Bool {
        guard isDragging, !cancelled else { return false }
        (cancelled, draft) = (true, nil)
        return true
    }
}

extension HaloProject {
    static let shapeControl = "halo.viewer.shape"

    /// Adds `drawn` through `addShape` and returns its id; nil with the reason on the Shape button.
    @discardableResult
    public mutating func drawShape(_ drawn: HaloShapeDrawn) -> String? {
        if let help = shapeHelp {
            refusal = HaloRefusal(control: Self.shapeControl, message: help)
            return nil
        }
        do { return try addShape(drawn.spec, in: drawn.box, name: drawn.name) } catch {
            refusal = HaloRefusal(control: Self.shapeControl, message: "\(error)")
            return nil
        }
    }
}
