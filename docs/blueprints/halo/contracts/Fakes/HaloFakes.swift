// Fakes/HaloFakes.swift: a small, predictable conformance of every Halo
// contract, so HaloApp's views, snapshots and journeys run before the live
// types land. Fakes ignore parenting and draw text as a box; everything else
// follows the contract's doc comment. Linux-safe. Never used by `.live`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import FlareCore

public struct FakeLayerPlacing: LayerPlacing {
    public init() {}
    public func value(_ property: HaloProperty, of layerID: String, in composition: HaloComposition, at frame: Int) -> Double? {
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else { return nil }
        if let track = layer.tracks[property.rawValue], let v = Timeline.value(of: track, at: Double(frame)) { return v }
        return layer.defaultValue(property, in: composition)
    }
    public func worldMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix? {
        func v(_ p: HaloProperty) -> Double { value(p, of: layerID, in: composition, at: frame) ?? 0 }
        guard composition.layers.contains(where: { $0.id == layerID }) else { return nil }
        return HaloMatrix.translation(x: v(.x), y: v(.y)) * HaloMatrix.rotation(degrees: v(.rotation))
            * HaloMatrix.scale(x: v(.scaleX), y: v(.scaleY)) * HaloMatrix.translation(x: -v(.anchorX), y: -v(.anchorY))
    }
    public func parentCandidates(for layerID: String, in composition: HaloComposition) -> [String] {
        composition.layers.map(\.id).filter { $0 != layerID }
    }
}

public struct FakeFrameDrawing: FrameDrawing {
    public init() {}
    public func drawList(_ composition: HaloComposition, at frame: Int) -> HaloDrawList {
        let placing = FakeLayerPlacing()
        let items = composition.layers.reversed().filter { $0.kind != .null && $0.isVisible(at: frame) }.map { layer in
            HaloDrawItem(
                layerID: layer.id, kind: layer.kind, bounds: layer.bounds(in: composition),
                matrix: placing.worldMatrix(of: layer.id, in: composition, at: frame) ?? .identity,
                opacity: placing.value(.opacity, of: layer.id, in: composition, at: frame) ?? 1,
                color: layer.color, blendMode: layer.blendMode, text: layer.text)
        }
        return HaloDrawList(width: composition.width, height: composition.height, frame: frame, items: items)
    }
}

public struct FakePropertyKeying: PropertyKeying {
    public init() {}
    public func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow] {
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else { return [] }
        let placing = FakeLayerPlacing()
        return HaloProperty.allCases.map { p in
            let value = placing.value(p, of: layerID, in: composition, at: frame) ?? 0
            let track = layer.tracks[p.rawValue] ?? []
            let state: HaloKeyState =
                track.count < 2 ? .notAnimated : track.contains { $0.frame == frame } ? .keyedHere : .animated
            return HaloPropertyRow(property: p, value: value, text: p.text(value), keyState: state)
        }
    }
    public func setValue(
        _ value: Double, for property: HaloProperty, of layerID: String, at frame: Int,
        in composition: inout HaloComposition
    ) throws {
        guard value.isFinite else { throw HaloEditError.notANumber(property) }
        let v = min(max(value, property.range.lowerBound), property.range.upperBound)
        try change(layerID, in: &composition) { layer in
            let track = layer.tracks[property.rawValue] ?? []
            if track.count >= 2 { layer.tracks[property.rawValue] = Self.keyed(track, frame: frame, value: v) }
            else if property == .opacity, track.isEmpty { layer.opacity = v }
            else { layer.tracks[property.rawValue] = [HaloKeyframe(frame: track.first?.frame ?? 0, value: v)] }
        }
    }
    public func toggleAnimation(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        let v = FakeLayerPlacing().value(property, of: layerID, in: composition, at: frame) ?? 0
        let last = composition.lastFrame
        try change(layerID, in: &composition) { layer in
            let track = layer.tracks[property.rawValue] ?? []
            if track.count >= 2 { layer.tracks[property.rawValue] = [HaloKeyframe(frame: 0, value: v)] }
            else { layer.tracks[property.rawValue] = Self.keyed(Self.keyed([], frame: frame, value: v), frame: frame == last ? 0 : last, value: v) }
        }
    }
    public func toggleKey(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        let v = FakeLayerPlacing().value(property, of: layerID, in: composition, at: frame) ?? 0
        try change(layerID, in: &composition) { layer in
            var track = layer.tracks[property.rawValue] ?? []
            if track.contains(where: { $0.frame == frame }) { track.removeAll { $0.frame == frame } }
            else { track = Self.keyed(track, frame: frame, value: v) }
            layer.tracks[property.rawValue] = track
        }
    }
    public func setParent(
        _ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        if let parentID, parentID == layerID { throw HaloEditError.parentCycle(layerID) }
        try change(layerID, in: &composition) { $0.parentID = parentID }
    }

    /// `track` with a key at `frame` set to `value`, kept sorted.
    static func keyed(_ track: [HaloKeyframe], frame: Int, value: Double) -> [HaloKeyframe] {
        var t = track.filter { $0.frame != frame }
        t.append(HaloKeyframe(frame: frame, value: value, easing: track.first { $0.frame == frame }?.easing ?? .linear))
        return t.sorted { $0.frame < $1.frame }
    }

    func change(_ layerID: String, in composition: inout HaloComposition, _ body: (inout HaloLayer) -> Void) throws {
        guard let i = composition.layers.firstIndex(where: { $0.id == layerID }) else {
            throw HaloEditError.unknownLayer(layerID)
        }
        body(&composition.layers[i])
    }
}

public struct FakeViewerDragging: ViewerDragging {
    public init() {}
    public func hit(_ composition: HaloComposition, at frame: Int, point: HaloPoint) -> String? {
        for item in FakeFrameDrawing().drawList(composition, at: frame).items.reversed() {
            guard let local = try? item.matrix.inverted().apply(point) else { continue }
            let b = item.bounds
            if local.x >= b.x, local.x <= b.x + b.width, local.y >= b.y, local.y <= b.y + b.height { return item.layerID }
        }
        return nil
    }
    public func commitMove(
        _ layerID: String, by delta: HaloPoint, at frame: Int, in composition: inout HaloComposition
    ) throws {
        guard delta.x != 0 || delta.y != 0 else { return }
        let placing = FakeLayerPlacing(), keying = FakePropertyKeying()
        guard let x = placing.value(.x, of: layerID, in: composition, at: frame),
            let y = placing.value(.y, of: layerID, in: composition, at: frame)
        else { throw HaloEditError.unknownLayer(layerID) }
        var copy = composition
        try keying.setValue(x + delta.x, for: .x, of: layerID, at: frame, in: &copy)
        try keying.setValue(y + delta.y, for: .y, of: layerID, at: frame, in: &copy)
        composition = copy
    }
}

public struct FakeKeyEasing: KeyEasing {
    public init() {}
    public func keys(of layerID: String, in composition: HaloComposition) -> [HaloKeyRef] {
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else { return [] }
        return HaloProperty.allCases.flatMap { p in
            (layer.tracks[p.rawValue] ?? []).map { HaloKeyRef(layerID: layerID, property: p, frame: $0.frame) }
        }
    }
    public func easing(of key: HaloKeyRef, in composition: HaloComposition) -> HaloEasing? {
        composition.layers.first { $0.id == key.layerID }?.tracks[key.property.rawValue]?.first { $0.frame == key.frame }?.easing
    }
    public func setEasing(_ easing: HaloEasing, on keys: Set<HaloKeyRef>, in composition: inout HaloComposition) throws {
        guard !keys.isEmpty else { throw HaloEditError.noKeySelected }
        var copy = composition
        for key in keys {
            guard let l = copy.layers.firstIndex(where: { $0.id == key.layerID }),
                let k = copy.layers[l].tracks[key.property.rawValue]?.firstIndex(where: { $0.frame == key.frame })
            else { throw HaloEditError.unknownLayer(key.layerID) }
            copy.layers[l].tracks[key.property.rawValue]?[k].easing = easing
        }
        composition = copy
    }
}

public struct FakeProjectHistory: ProjectHistory {
    public let limit = 100
    public init() {}
    public func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory) {
        if let coalesceKey, history.undo.last?.coalesceKey == coalesceKey { return }
        history.undo.append(HaloHistoryEntry(name: name, before: before, coalesceKey: coalesceKey))
        if history.undo.count > limit { history.undo.removeFirst() }
        history.redo = []
    }
    public func undo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        guard let step = history.undo.popLast() else { return nil }
        history.redo.append(HaloHistoryEntry(name: step.name, before: current))
        return step.before
    }
    public func redo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        guard let step = history.redo.popLast() else { return nil }
        history.undo.append(HaloHistoryEntry(name: step.name, before: current))
        return step.before
    }
}

public struct FakeProjectFiles: ProjectFiles {
    public init() {}
    public func encode(_ state: HaloDocumentState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }
    public func decode(_ data: Data) throws -> HaloDocumentState {
        do { return try JSONDecoder().decode(HaloDocumentState.self, from: data) } catch {
            throw HaloFileError.notAHaloFile
        }
    }
}

public struct FakePlaybackClock: PlaybackClock {
    public init() {}
    public func tick(
        startFrame: Int, elapsed: Double, framesPerSecond: Int, durationFrames: Int, loops: Bool
    ) -> HaloPlaybackTick {
        guard durationFrames > 0, framesPerSecond > 0, elapsed.isFinite, elapsed > 0 else {
            return HaloPlaybackTick(frame: max(0, min(startFrame, durationFrames - 1)), ended: false)
        }
        let ahead = Int(min(elapsed * Double(framesPerSecond), 1e9))
        let raw = startFrame + ahead
        if loops { return HaloPlaybackTick(frame: raw % durationFrames, ended: false) }
        return raw >= durationFrames - 1
            ? HaloPlaybackTick(frame: durationFrames - 1, ended: true) : HaloPlaybackTick(frame: raw, ended: false)
    }
}

/// Fills the frame with the top item's color: enough for the viewer to show
/// "a rendered frame" and for render loops to count frames.
public struct FakeFrameRendering: FrameRendering {
    public init() {}
    public func render(_ list: HaloDrawList, scale: Int, text: (any TextRasterizing)?) throws -> HaloRenderedFrame {
        let s = max(scale, 1)
        let top = list.items.last.map { RGBA(r: Float($0.color.red), g: Float($0.color.green), b: Float($0.color.blue), a: 1) }
        let pixels = try PixelBuffer(width: max(1, list.width / s), height: max(1, list.height / s), fill: top ?? .clear)
        let skipped = text == nil ? list.items.filter { $0.kind == .text }.count : 0
        return HaloRenderedFrame(pixels: pixels, frame: list.frame, skippedLayerCount: skipped)
    }
}

public struct FakeTextRasterizer: TextRasterizing {
    public init() {}
    public func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer {
        let w = max(1, Int(text.fontSize * 0.6 * Double(max(text.string.count, 1))))
        return try PixelBuffer(
            width: w, height: max(1, Int(text.fontSize)),
            fill: RGBA(r: Float(color.red), g: Float(color.green), b: Float(color.blue), a: 1))
    }
}

public struct FakeCompositionRendering: CompositionRendering {
    public init() {}
    public func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan {
        guard composition.durationFrames > 0 else { throw HaloEditError.noComposition }
        let even = { (n: Int) in max(2, n / 2 / 2 * 2) }
        let w = settings.halfSize ? even(composition.width) : composition.width
        let h = settings.halfSize ? even(composition.height) : composition.height
        let frames = Array(0..<composition.durationFrames)
        let names: [String] = switch settings.format {
        case .movie: ["\(composition.name).mp4"]
        case .pngSequence: frames.map { f in
            let n = String(f + 1)
            return "\(composition.name)_\(String(repeating: "0", count: max(0, 4 - n.count)))\(n).png"
        }
        }
        return HaloRenderPlan(width: w, height: h, framesPerSecond: composition.framesPerSecond, frames: frames, fileNames: names)
    }
    public func run(
        _ plan: HaloRenderPlan, of composition: HaloComposition, into sink: inout some RenderSink,
        isCancelled: () -> Bool
    ) -> HaloRenderOutcome {
        do { try sink.begin(plan) } catch { return .failed(frame: 0, message: "\(error)") }
        for (i, frame) in plan.frames.enumerated() {
            if isCancelled() {
                try? sink.finish(cancelled: true)
                return .cancelled(frames: i)
            }
            do {
                let list = FakeFrameDrawing().drawList(composition, at: frame)
                let image = try FakeFrameRendering().render(list, scale: 1, text: nil)
                let name = plan.fileNames.count == plan.frames.count ? plan.fileNames[i] : plan.fileNames.first ?? ""
                try sink.write(image, named: name)
            } catch {
                try? sink.finish(cancelled: true)
                return .failed(frame: frame, message: "\(error)")
            }
        }
        do { try sink.finish(cancelled: false) } catch { return .failed(frame: plan.frames.last ?? 0, message: "\(error)") }
        return .finished(frames: plan.frames.count)
    }
}
