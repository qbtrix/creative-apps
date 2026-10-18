// FlareSelectionRead.swift: what the stage says about the selection (stage-edit SE-1): the count, the box, the shared
// scale and rotation and SE-0's handles, read live, so a handle drag shows "scale 1.50 × 1.50" before mouse-up.
import FlareCore
import SuiteKernel

/// The selection as the stage shows it: `box` in scene points with rotation applied (the world bounds), nil with
/// nothing selected; `rotation` (degrees), `scaleX` and `scaleY` nil when the selected layers differ.
public struct SelectionReadout: Sendable, Equatable {
    public var count: Int
    public var box: Rect?
    public var rotation: Double?
    public var scaleX: Double?, scaleY: Double?
    public var handles: [StageHandle]

    /// The readout in words, as `flare.stage.selection` carries it: "2 selected, scale 1.50 × 1.50, rotation 90°";
    /// a value the layers don't share reads "mixed".
    public var text: String {
        let x = scaleX.map { Self.fixed($0, places: 2) } ?? "mixed"
        let y = scaleY.map { Self.fixed($0, places: 2) } ?? "mixed"
        let turn = rotation.map { Self.fixed($0, places: 0) + "°" } ?? "mixed"
        return "\(count) selected, scale \(x) × \(y), rotation \(turn)"
    }

    /// Each handle as a `handleSize`-wide square (on screen) in scene points round its point, keyed by the kernel's name
    /// for it, as `SelectionHandles` draws them.
    public func handleRects(stageScale: Double = 1) -> [EditorHandle: Rect] {
        let half = FlareWorkspace.handleSize / FlareWorkspace.usable(stageScale) / 2
        return Dictionary(handles.map { h in
            (h.editorHandle, Rect(minX: h.point.x - half, minY: h.point.y - half, maxX: h.point.x + half, maxY: h.point.y + half))
        }, uniquingKeysWith: { first, _ in first })
    }

    /// `value` with `places` decimals, rounded half away from zero; "-0" reads "0". Foundation-free, so Linux-safe.
    static func fixed(_ value: Double, places: Int) -> String {
        var factor = 1.0
        for _ in 0..<max(0, places) { factor *= 10 }
        let scaled = (abs(value) * factor).rounded()
        guard scaled.isFinite, scaled < 1e15 else { return value.isNaN ? "mixed" : (value < 0 ? "-∞" : "∞") }
        let n = Int(scaled), unit = Int(factor)
        let whole = n / unit, fraction = String(n % unit)
        let sign = value < 0 && n != 0 ? "-" : ""
        guard places > 0 else { return sign + String(whole) }
        return sign + String(whole) + "." + String(repeating: "0", count: max(0, places - fraction.count)) + fraction
    }
}

extension FlareWorkspace {
    /// The selection readout for a stage at scale 1.
    public var selectionReadout: SelectionReadout { selectionReadout(stageScale: 1) }

    /// The selection readout, its rotate zone 2 × `handleSize` stage points above the box at `stageScale`. Select
    /// counts layers, Direct Select items. A handle drag under way reads its preview: the resized box, `boxResult`.
    public func selectionReadout(stageScale: Double) -> SelectionReadout {
        var box = selection.isEmpty ? nil : selectionBounds, changes: [String: [String: Double]] = [:]
        if let g = gesture, let grip = g.grip, !g.isClick, g.start.isFinite, g.end.isFinite, let sceneID = selectedSceneID,
           let document {
            let keys: EditModifiers = g.modifiers.contains(.shift) ? .shift : []
            let delta = Point(x: g.end.x - g.start.x, y: g.end.y - g.start.y)
            box = grip.handle.boxIndex == nil
                ? grip.box : BoxMath.resized(grip.box, grip.handle.editorHandle, by: delta, modifiers: keys)
            changes = services.shapes.boxResult(Self.boxGesture(grip, from: g.start, to: g.end, modifiers: g.modifiers),
                                                layers: selectedLayerIDs, document: document, sceneID: sceneID,
                                                frame: currentFrame, box: grip.box)
        }
        let values = selectedLayerIDs.compactMap { id -> [String: Double]? in
            guard let owner = selection.first(where: { $0.layerID == id })?.owner,
                  let t = document?.layers(of: owner)?.first(where: { $0.id == id })?.placement(at: Double(currentFrame))
                      .transform else { return nil }
            return ["rotation": t.rotation, "scaleX": t.scaleX, "scaleY": t.scaleY].merging(changes[id] ?? [:]) { $1 }
        }
        func shared(_ key: String) -> Double? { Self.shared(values.compactMap { $0[key] }) }
        return SelectionReadout(count: tool == .select ? selectedLayerIDs.count : selection.count, box: box,
                                rotation: shared("rotation"), scaleX: shared("scaleX"), scaleY: shared("scaleY"),
                                handles: box.map { handles(of: $0, rotation: 0, stageScale: stageScale) } ?? [])
    }

    /// The value every entry shares (within 1e-9), or nil when they differ or there are none.
    static func shared(_ values: [Double]) -> Double? {
        guard let first = values.first, values.allSatisfy({ abs($0 - first) <= 1e-9 }) else { return nil }
        return first
    }
}
