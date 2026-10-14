// Fakes/HaloFakes.swift: a small, predictable conformance of every Halo
// contract, so HaloApp's views, snapshots and journeys run before the live
// types land. Each fake keeps its contract's doc comment; where it is
// simpler than the live type it says so here:
// - FakeFrameRendering fills each item's axis-aligned world box with its
//   color (no blend modes, no anti-aliasing); FakeTextRasterizer draws a box.
// - FakeProjectFiles checks the envelope, version and size, but not the
//   contents' rules (unique names, spans, sorted keys, cycles).
// Linux-safe. Never used by `.live`.
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
        guard composition.layers.contains(where: { $0.id == layerID }) else { return nil }
        var matrix = localMatrix(of: layerID, in: composition, at: frame)
        var seen: Set<String> = [layerID]
        var next = composition.layers.first { $0.id == layerID }?.parentID
        while let parent = next, !seen.contains(parent), composition.layers.contains(where: { $0.id == parent }) {
            matrix = localMatrix(of: parent, in: composition, at: frame) * matrix
            seen.insert(parent)
            next = composition.layers.first { $0.id == parent }?.parentID
        }
        return matrix
    }
    public func parentCandidates(for layerID: String, in composition: HaloComposition) -> [String] {
        composition.layers.map(\.id).filter { $0 != layerID && !Self.follows($0, layerID, in: composition) }
    }

    func localMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix {
        func v(_ p: HaloProperty) -> Double { value(p, of: layerID, in: composition, at: frame) ?? 0 }
        return HaloMatrix.translation(x: v(.x), y: v(.y)) * HaloMatrix.rotation(degrees: v(.rotation))
            * HaloMatrix.scale(x: v(.scaleX), y: v(.scaleY)) * HaloMatrix.translation(x: -v(.anchorX), y: -v(.anchorY))
    }

    /// Whether `layerID` follows `ancestorID` through its chain of parents.
    static func follows(_ layerID: String, _ ancestorID: String, in composition: HaloComposition) -> Bool {
        var seen: Set<String> = []
        var next = composition.layers.first { $0.id == layerID }?.parentID
        while let id = next, seen.insert(id).inserted {
            if id == ancestorID { return true }
            next = composition.layers.first { $0.id == id }?.parentID
        }
        return false
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
            else { Self.setStatic(v, property, of: &layer) }
        }
    }
    public func toggleAnimation(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        guard let v = FakeLayerPlacing().value(property, of: layerID, in: composition, at: frame) else {
            throw HaloEditError.unknownLayer(layerID)
        }
        let last = composition.lastFrame
        try change(layerID, in: &composition) { layer in
            if (layer.tracks[property.rawValue] ?? []).count >= 2 { Self.setStatic(v, property, of: &layer) }
            else {
                layer.tracks[property.rawValue] = Self.keyed(
                    Self.keyed([], frame: frame, value: v), frame: frame == last ? 0 : last, value: v)
            }
        }
    }
    public func toggleKey(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        guard let v = FakeLayerPlacing().value(property, of: layerID, in: composition, at: frame) else {
            throw HaloEditError.unknownLayer(layerID)
        }
        try change(layerID, in: &composition) { layer in
            var track = layer.tracks[property.rawValue] ?? []
            if track.contains(where: { $0.frame == frame }) { track.removeAll { $0.frame == frame } }
            else { track = Self.keyed(track, frame: frame, value: v) }
            if track.count < 2 {
                Self.setStatic(track.first?.value ?? v, property, of: &layer)
            } else {
                layer.tracks[property.rawValue] = track
            }
        }
    }
    public func setParent(
        _ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else {
            throw HaloEditError.unknownLayer(layerID)
        }
        if let parentID {
            guard composition.layers.contains(where: { $0.id == parentID }) else { throw HaloEditError.unknownLayer(parentID) }
            if parentID == layerID || FakeLayerPlacing.follows(parentID, layerID, in: composition) {
                throw HaloEditError.parentCycle(layer.name)
            }
        }
        let placing = FakeLayerPlacing()
        guard let world = placing.worldMatrix(of: layerID, in: composition, at: frame),
            let ax = placing.value(.anchorX, of: layerID, in: composition, at: frame),
            let ay = placing.value(.anchorY, of: layerID, in: composition, at: frame)
        else { throw HaloEditError.unknownLayer(layerID) }
        let onScreen = world.apply(HaloPoint(x: ax, y: ay))
        var copy = composition
        try change(layerID, in: &copy) { $0.parentID = parentID }
        let parentWorld = parentID.flatMap { placing.worldMatrix(of: $0, in: copy, at: frame) } ?? .identity
        guard let local = try? parentWorld.inverted().apply(onScreen) else { throw HaloEditError.parentCycle(layer.name) }
        try setValue(local.x, for: .x, of: layerID, at: frame, in: &copy)
        try setValue(local.y, for: .y, of: layerID, at: frame, in: &copy)
        composition = copy
    }

    /// The not-animated home of a value: `opacity` on the layer, every other
    /// property a one-key track at frame 0.
    static func setStatic(_ value: Double, _ property: HaloProperty, of layer: inout HaloLayer) {
        if property == .opacity {
            layer.opacity = value
            layer.tracks[property.rawValue] = nil
        } else {
            layer.tracks[property.rawValue] = [HaloKeyframe(frame: 0, value: value)]
        }
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
        guard let layer = composition.layers.first(where: { $0.id == layerID }),
            let x = placing.value(.x, of: layerID, in: composition, at: frame),
            let y = placing.value(.y, of: layerID, in: composition, at: frame)
        else { throw HaloEditError.unknownLayer(layerID) }
        // The delta is in composition space; a parented layer moves in its parent's.
        let parentWorld = layer.parentID.flatMap { placing.worldMatrix(of: $0, in: composition, at: frame) } ?? .identity
        let inverse = (try? parentWorld.inverted()) ?? .identity
        let origin = inverse.apply(HaloPoint(x: 0, y: 0)), moved = inverse.apply(delta)
        var copy = composition
        try keying.setValue(x + moved.x - origin.x, for: .x, of: layerID, at: frame, in: &copy)
        try keying.setValue(y + moved.y - origin.y, for: .y, of: layerID, at: frame, in: &copy)
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
        history.redo = []
        if let coalesceKey, history.undo.last?.coalesceKey == coalesceKey { return }
        history.undo.append(HaloHistoryEntry(name: name, before: before, coalesceKey: coalesceKey))
        if history.undo.count > limit { history.undo.removeFirst() }
    }
    public func endCoalescing(in history: inout HaloHistory) {
        guard !history.undo.isEmpty else { return }
        history.undo[history.undo.count - 1].coalesceKey = nil
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

/// The file envelope both the fake and the live type write.
struct HaloFileEnvelope: Codable {
    var format: String
    var version: Int
    var project: HaloDocumentState?
}

public struct FakeProjectFiles: ProjectFiles {
    public static let maxBytes = 64 * 1024 * 1024
    public init() {}
    public func encode(_ state: HaloDocumentState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(HaloFileEnvelope(format: "halo", version: 1, project: state))
    }
    public func decode(_ data: Data) throws -> HaloDocumentState {
        guard data.count <= Self.maxBytes else { throw HaloFileError.tooLarge }
        guard let head = try? JSONDecoder().decode(Header.self, from: data), head.format == "halo" else {
            throw HaloFileError.notAHaloFile
        }
        guard head.version <= 1 else { throw HaloFileError.newerVersion(head.version) }
        do {
            guard let project = try JSONDecoder().decode(HaloFileEnvelope.self, from: data).project else {
                throw HaloFileError.damaged("it has no project")
            }
            return project
        } catch let error as HaloFileError { throw error } catch { throw HaloFileError.damaged("\(error)") }
    }
    struct Header: Codable { var format: String; var version: Int }
}

public struct FakePlaybackClock: PlaybackClock {
    public init() {}
    public func tick(
        startFrame: Int, elapsed: Double, framesPerSecond: Int, durationFrames: Int, loops: Bool
    ) -> HaloPlaybackTick {
        guard durationFrames > 0, framesPerSecond > 0, elapsed.isFinite, elapsed > 0 else {
            return HaloPlaybackTick(frame: max(0, min(startFrame, durationFrames - 1)), ended: false)
        }
        // The same 1e-9 as FlareCore's playbackFrame, so fake and live agree on frame edges.
        let ahead = Int(min((elapsed * Double(framesPerSecond) + 1e-9).rounded(.down), 1e9))
        let raw = startFrame + ahead
        if loops { return HaloPlaybackTick(frame: raw % durationFrames, ended: false) }
        return raw >= durationFrames - 1
            ? HaloPlaybackTick(frame: durationFrames - 1, ended: true) : HaloPlaybackTick(frame: raw, ended: false)
    }
}

/// Fills each item's axis-aligned world box with its color, bottom first.
public struct FakeFrameRendering: FrameRendering {
    public init() {}
    public func render(_ list: HaloDrawList, width: Int, height: Int, text: (any TextRasterizing)?) throws -> HaloRenderedFrame {
        var pixels = try PixelBuffer(width: max(1, width), height: max(1, height))
        let sx = Double(pixels.width) / Double(max(1, list.width)), sy = Double(pixels.height) / Double(max(1, list.height))
        var skipped = 0
        for item in list.items {
            if item.kind == .text, text == nil { skipped += 1; continue }
            let b = item.bounds
            let corners = [(b.x, b.y), (b.x + b.width, b.y), (b.x, b.y + b.height), (b.x + b.width, b.y + b.height)]
                .map { item.matrix.apply(HaloPoint(x: $0.0, y: $0.1)) }
            guard let minX = corners.map(\.x).min(), let maxX = corners.map(\.x).max(),
                let minY = corners.map(\.y).min(), let maxY = corners.map(\.y).max()
            else { continue }
            let a = Float(item.opacity)
            let color = RGBA(r: Float(item.color.red) * a, g: Float(item.color.green) * a, b: Float(item.color.blue) * a, a: a)
            let x0 = max(0, Int(minX * sx)), x1 = min(pixels.width, Int(maxX * sx))
            let y0 = max(0, Int(minY * sy)), y1 = min(pixels.height, Int(maxY * sy))
            guard x0 < x1, y0 < y1 else { continue }
            for y in y0..<y1 { for x in x0..<x1 { try pixels.setPixel(x: x, y: y, color) } }
        }
        return HaloRenderedFrame(pixels: pixels, frame: list.frame, skippedLayerCount: skipped)
    }
}

public struct FakeTextRasterizer: TextRasterizing {
    public init() {}
    public func measure(_ text: HaloTextContent) -> HaloLayerRect {
        let estimate = HaloTextContent(string: text.string, fontSize: text.fontSize)
        return HaloLayerRect(x: 0, y: 0, width: estimate.width, height: estimate.height)
    }
    public func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer {
        let box = measure(text)
        return try PixelBuffer(
            width: max(1, Int(box.width)), height: max(1, Int(box.height)),
            fill: RGBA(r: Float(color.red), g: Float(color.green), b: Float(color.blue), a: 1))
    }
}

public struct FakeCompositionRendering: CompositionRendering {
    public init() {}
    public func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan {
        guard composition.durationFrames > 0 else { throw HaloEditError.noComposition }
        let half = { (n: Int) in max(2, n / 2 / 2 * 2) }
        let w = settings.halfSize ? half(composition.width) : composition.width
        let h = settings.halfSize ? half(composition.height) : composition.height
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
        _ plan: HaloRenderPlan, of composition: HaloComposition, text: (any TextRasterizing)?,
        into sink: inout some RenderSink, isCancelled: () -> Bool
    ) -> HaloRenderOutcome {
        do { try sink.begin(plan) } catch { return .failed(frame: 0, message: "\(error)") }
        for (i, frame) in plan.frames.enumerated() {
            if isCancelled() {
                try? sink.finish(cancelled: true)
                return .cancelled(frames: i)
            }
            do {
                let list = FakeFrameDrawing().drawList(composition, at: frame)
                let image = try FakeFrameRendering().render(list, width: plan.width, height: plan.height, text: text)
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
