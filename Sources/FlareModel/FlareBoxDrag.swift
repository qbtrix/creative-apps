// FlareBoxDrag.swift: scale and rotate by the selection box (docs/blueprints/flare/features/stage-edit.md, SE-0). A
// Select drag that starts on one of the box's eight handles or its rotate zone previews `ShapeBuilding.boxResult` on
// the stage's list and commits one "Scale" or "Rotate" through `commitBox` at mouse-up. The box and handle math is
// SuiteKernel's (`BoxMath`, `HandleHit`, rule 20); this file only maps it onto Flare's handles and gestures.
#if canImport(Glibc)
import Glibc  // atan2
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import FlareCore
import SuiteKernel

/// One handle of the selection box, in scene points: a corner or an edge's middle (0...3 clockwise from the top-left
/// corner, or from the top edge), or the rotate zone above the top edge.
public struct StageHandle: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case corner(Int), edge(Int), rotate }
    public var kind: Kind, point: Point
    public init(kind: Kind, point: Point) { self.kind = kind; self.point = point }

    /// The kernel's handle for each kind, in the order `handles(of:rotation:)` lists them.
    static let kinds: [(EditorHandle, Kind)] = [
        (.topLeft, .corner(0)), (.topRight, .corner(1)), (.bottomRight, .corner(2)), (.bottomLeft, .corner(3)),
        (.top, .edge(0)), (.right, .edge(1)), (.bottom, .edge(2)), (.left, .edge(3)), (.rotate, .rotate),
    ]

    /// The kernel's name for this handle.
    var editorHandle: EditorHandle { Self.kinds.first { $0.1 == kind }?.0 ?? .rotate }

    /// `BoxGesture.scale`'s handle number, 0...7 clockwise from the top-left; nil for the rotate zone.
    var boxIndex: Int? {
        switch kind {
        case .corner(let i): 2 * i
        case .edge(let i): 2 * i + 1
        case .rotate: nil
        }
    }
}

/// The handle a Select drag holds, and the selection box it started on.
struct BoxGrip: Equatable, Sendable {
    var handle: StageHandle, box: Rect
}

extension FlareWorkspace {
    /// The side of a handle's square in stage points; the rotate zone sits two sides above the top edge (`BoxMath`).
    public static let handleSize = 12.0

    /// The box's 4 corners, 4 edge middles and the rotate zone, turned `rotation` degrees about its centre. The rotate
    /// zone sits 2 × `handleSize` stage points above the top edge at any `stageScale`.
    public func handles(of box: Rect, rotation: Double, stageScale: Double = 1) -> [StageHandle] {
        let squares = BoxMath.handles(of: box, size: Self.handleSize / Self.usable(stageScale))
        let centre = Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2)
        let turn = Matrix.rotation(degrees: rotation.isFinite ? rotation : 0)
        return StageHandle.kinds.compactMap { handle, kind in
            guard let r = squares[handle] else { return nil }
            let p = turn.apply(Point(x: (r.minX + r.maxX) / 2 - centre.x, y: (r.minY + r.maxY) / 2 - centre.y))
            return StageHandle(kind: kind, point: Point(x: centre.x + p.x, y: centre.y + p.y))
        }
    }

    /// The selection box's handle within `hitSlop` stage points of `point`, or nil: a resize handle first
    /// (`HandleHit`), else the rotate zone. Only Select on the scene has handles, since the box commit keys scene layers.
    func handle(at point: Point, stageScale: Double) -> StageHandle? {
        guard tool == .select, editingSymbolID == nil, point.isFinite, !selectKeysSymbol(selection),
              let box = selectionBounds else { return nil }
        let tolerance = HandleHit.tolerance(screen: Self.hitSlop, zoom: stageScale)
        let all = handles(of: box, rotation: 0, stageScale: stageScale)
        if let hit = HandleHit.handle(at: point, in: box, tolerance: tolerance), hit != .inside {
            return all.first { $0.editorHandle == hit }
        }
        return all.first { $0.kind == .rotate && max(abs($0.point.x - point.x), abs($0.point.y - point.y)) <= tolerance }
    }

    /// The handle under `point` with the box it is on, for a new gesture; nil off every handle.
    func grip(at point: Point, stageScale: Double) -> BoxGrip? {
        guard let handle = handle(at: point, stageScale: stageScale), let box = selectionBounds else { return nil }
        return BoxGrip(handle: handle, box: box)
    }

    /// What a drag of `grip` from `start` to `end` asks of the box: a scale that moves the held handle with the
    /// pointer (`BoxMath.resized`, Shift keeping the aspect), or a turn about the box centre (Shift snaps to 15°).
    static func boxGesture(_ grip: BoxGrip, from start: Point, to end: Point, modifiers: DragModifiers) -> BoxGesture {
        let keys: EditModifiers = modifiers.contains(.shift) ? .shift : []
        guard let index = grip.handle.boxIndex else {
            let c = Point(x: (grip.box.minX + grip.box.maxX) / 2, y: (grip.box.minY + grip.box.maxY) / 2)
            let turn = (atan2(end.y - c.y, end.x - c.x) - atan2(start.y - c.y, start.x - c.x)) * 180 / .pi
            let degrees = turn.isFinite ? (turn + 540).truncatingRemainder(dividingBy: 360) - 180 : 0
            return .rotate(degrees: BoxMath.snappedDegrees(degrees, modifiers: keys))
        }
        let delta = Point(x: end.x - start.x, y: end.y - start.y)
        let resized = BoxMath.resized(grip.box, grip.handle.editorHandle, by: delta, modifiers: keys)
        return .scale(handle: index, to: BoxGestureMath.handle(index, on: resized))
    }

    /// The stage at the playhead with `gesture`'s `boxResult` applied to the selected layers; nothing is committed.
    func boxPreview(_ gesture: BoxGesture, box: Rect) -> StageDrawList? {
        guard let sceneID = selectedSceneID, let document else { return nil }
        let frame = currentFrame
        var list = services.stage.drawList(document, sceneID: sceneID, frame: frame, editing: nil)
        let changes = services.shapes.boxResult(gesture, layers: selectedLayerIDs, document: document, sceneID: sceneID,
                                                frame: frame, box: box)
        for layer in document.layers(of: .scene(sceneID)) ?? [] {
            guard let values = changes[layer.id] else { continue }
            let old = layer.placement(at: Double(frame)).transform
            var new = old
            new.x = values["x"] ?? old.x; new.y = values["y"] ?? old.y
            new.scaleX = values["scaleX"] ?? old.scaleX; new.scaleY = values["scaleY"] ?? old.scaleY
            new.rotation = values["rotation"] ?? old.rotation
            // A layer scaled to 0 draws nothing, so there is nothing to carry over.
            guard let back = try? old.matrix.inverted() else { continue }
            let delta = new.matrix * back
            for (i, item) in list.items.enumerated() where item.address.layerID == layer.id {
                list.items[i].transform = delta * item.transform
            }
        }
        return list
    }

    /// Mouse-up on a handle drag: one "Scale" or "Rotate" of the selected layers; the selection stays.
    mutating func commitBox(_ grip: BoxGrip, _ g: StageGesture) {
        guard let sceneID = selectedSceneID, g.start.isFinite, g.end.isFinite else { return }
        let gesture = Self.boxGesture(grip, from: g.start, to: g.end, modifiers: g.modifiers)
        let shapes = services.shapes, layers = selectedLayerIDs, frame = currentFrame, autoKey = autoKey, kept = selection
        step { try shapes.commitBox(gesture, layers: layers, sceneID: sceneID, frame: frame, box: grip.box,
                                    autoKey: autoKey, in: &$0) }
        if layerError == nil { setSelection(kept) }
    }
}
