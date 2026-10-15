// State.swift: the row and state values the workspace stores and views read (blueprint part 6.6).
// W0 copies this file into Sources/PrismModel/Contracts/PrismState.swift, so PrismWorkspace.swift
// can declare every stored property v1 needs before the features that fill them land.
// Invariants: plain Sendable values; each is written only by the feature file 6.6 names.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A refused edit: the sentence and the control it shows under (`prism.<area>.<name>`).
public struct PrismRefusal: Sendable, Hashable {
    public var message: String, control: String
    public init(message: String, control: String) { self.message = message; self.control = control }
}

/// One outliner row: depth for the tree, the kind's SF Symbol name, visibility.
public struct PrismOutlinerRow: Sendable, Hashable, Identifiable {
    public var id: PrismID, name: String, depth: Int, symbol: String, isVisible: Bool, isSelected: Bool
    public init(id: PrismID, name: String, depth: Int, symbol: String, isVisible: Bool, isSelected: Bool) {
        self.id = id; self.name = name; self.depth = depth; self.symbol = symbol; self.isVisible = isVisible; self.isSelected = isSelected
    }
}

/// One keyable or plain number row in any inspector section (TRANSFORM, LIGHT, CAMERA, MATERIAL, SCENE).
/// `property` is nil for rows that can't be keyed (metallic, roughness, near, far).
public struct PrismPropertyRow: Sendable, Hashable, Identifiable {
    public enum KeyState: String, Sendable, Hashable { case notAnimated, animated, keyedHere }
    public var id: String, title: String, value: Double, text: String, unit: String, decimals: Int
    public var property: PrismProperty?, keyState: KeyState, isEnabled: Bool, help: String?
    public init(id: String, title: String, value: Double, text: String, unit: String, decimals: Int,
                property: PrismProperty?, keyState: KeyState, isEnabled: Bool, help: String?) {
        self.id = id; self.title = title; self.value = value; self.text = text; self.unit = unit; self.decimals = decimals
        self.property = property; self.keyState = keyState; self.isEnabled = isEnabled; self.help = help
    }
}

/// What the SwiftUI overlay draws over the RealityView, all in normalized viewport points.
public struct PrismOverlayGeometry: Sendable, Hashable {
    public struct Handle: Sendable, Hashable { public var handle: PrismGizmoHandle, from: ViewPoint, to: ViewPoint
        public init(handle: PrismGizmoHandle, from: ViewPoint, to: ViewPoint) { self.handle = handle; self.from = from; self.to = to } }
    public var outline: [[ViewPoint]], points: [ViewPoint], selectedPoints: [ViewPoint]
    public var segments: [(ViewPoint, ViewPoint)], selectedSegments: [(ViewPoint, ViewPoint)], handles: [Handle]
    public init(outline: [[ViewPoint]] = [], points: [ViewPoint] = [], selectedPoints: [ViewPoint] = [],
                segments: [(ViewPoint, ViewPoint)] = [], selectedSegments: [(ViewPoint, ViewPoint)] = [], handles: [Handle] = []) {
        self.outline = outline; self.points = points; self.selectedPoints = selectedPoints; self.segments = segments
        self.selectedSegments = selectedSegments; self.handles = handles
    }
    public static func == (a: Self, b: Self) -> Bool {
        a.outline == b.outline && a.points == b.points && a.selectedPoints == b.selectedPoints && a.handles == b.handles
            && a.segments.map { [$0.0, $0.1] } == b.segments.map { [$0.0, $0.1] }
            && a.selectedSegments.map { [$0.0, $0.1] } == b.selectedSegments.map { [$0.0, $0.1] }
    }
    public func hash(into h: inout Hasher) { h.combine(points); h.combine(handles); h.combine(segments.count) }
}

/// One timeline lane: an object and its key frames.
public struct PrismTimelineRow: Sendable, Hashable, Identifiable {
    public var id: PrismID, name: String, keyFrames: [Int], isSelected: Bool
    public init(id: PrismID, name: String, keyFrames: [Int], isSelected: Bool) {
        self.id = id; self.name = name; self.keyFrames = keyFrames; self.isSelected = isSelected
    }
}

/// A key and the next one on a track, with its easing ("Rotation Y 0 → 89", "Ease In and Out").
public struct PrismKeySegment: Sendable, Hashable, Identifiable {
    public var from: PrismKeyRef, toFrame: Int, easing: PrismEasing, isSelected: Bool
    public var id: PrismKeyRef { from }
    public var title: String { "\(from.property.title) \(from.frame) → \(toFrame)" }
    public init(from: PrismKeyRef, toFrame: Int, easing: PrismEasing, isSelected: Bool) {
        self.from = from; self.toFrame = toFrame; self.easing = easing; self.isSelected = isSelected
    }
}

/// A modeling tool drag in progress: the kind, where it began, the typed amount if any.
public struct PrismToolDrag: Sendable, Hashable {
    public var kind: PrismMeshOpKind, start: ViewPoint, amount: Double, typed: String?, cuts: Int, before: PrismMesh
    public init(kind: PrismMeshOpKind, start: ViewPoint, amount: Double, typed: String?, cuts: Int, before: PrismMesh) {
        self.kind = kind; self.start = start; self.amount = amount; self.typed = typed; self.cuts = cuts; self.before = before
    }
}

public enum PrismJobPhase: Sendable, Hashable { case idle, running(done: Int, of: Int), finished, failed(String), cancelled }

public struct PrismImportJob: Sendable, Hashable {
    public var name: String, format: PrismImportFormat, phase: PrismJobPhase, note: [String]
    public init(name: String, format: PrismImportFormat, phase: PrismJobPhase = .idle, note: [String] = []) {
        self.name = name; self.format = format; self.phase = phase; self.note = note
    }
}

/// The Render… sheet's choices and the running job.
public struct PrismRenderDraft: Sendable, Hashable {
    public var format: PrismRenderFormat, firstFrame: Int, lastFrame: Int, halfSize: Bool, transparent: Bool
    public var phase: PrismJobPhase, files: [String]
    public init(format: PrismRenderFormat = .pngSequence, firstFrame: Int = 0, lastFrame: Int = 0, halfSize: Bool = false,
                transparent: Bool = false, phase: PrismJobPhase = .idle, files: [String] = []) {
        self.format = format; self.firstFrame = firstFrame; self.lastFrame = lastFrame; self.halfSize = halfSize
        self.transparent = transparent; self.phase = phase; self.files = files
    }
    /// The sheet's note when the scene has no active camera (P-F14): it renders the view instead.
    public static func cameraNote(for scene: PrismScene) -> String? {
        scene.activeCameraID.flatMap { scene.node($0) } == nil ? "No camera: rendering the view." : nil
    }
}

/// The New Scene sheet's typed fields.
public struct PrismNewSceneDraft: Sendable, Hashable {
    public var name: String, width: String, height: String, lengthSeconds: String, framesPerSecond: Int
    public init(name: String = "Untitled Scene", width: String = "1920", height: String = "1080",
                lengthSeconds: String = "3", framesPerSecond: Int = 30) {
        self.name = name; self.width = width; self.height = height; self.lengthSeconds = lengthSeconds
        self.framesPerSecond = framesPerSecond
    }
    public var problems: [PrismSceneField: String] {
        PrismSceneSettings.problems(width: width, height: height, lengthSeconds: lengthSeconds, framesPerSecond: framesPerSecond).problems
    }
}

public struct PrismPlaybackState: Sendable, Hashable {
    public var isPlaying: Bool, loops: Bool, startFrame: Int, startTime: Double, frame: Int
    public init(isPlaying: Bool = false, loops: Bool = true, startFrame: Int = 0, startTime: Double = 0, frame: Int = 0) {
        self.isPlaying = isPlaying; self.loops = loops; self.startFrame = startFrame; self.startTime = startTime; self.frame = frame
    }
}
