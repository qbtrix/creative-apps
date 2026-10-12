// HaloProject.swift: the state behind Halo's window (motion graphics). Holds
// the project's compositions and the selected one. Linux-safe: no UI imports.
// HaloApp changes it only through the methods here. The composition model
// (H1) replaces `HaloComposition` with layers, in and out points.

/// A composition: a sized, timed canvas that layers play in.
public struct HaloComposition: Identifiable, Sendable, Hashable {
    public let id: String
    public var name: String
    public var width: Int
    public var height: Int
    public var framesPerSecond: Int
    public var durationFrames: Int

    public init(id: String, name: String, width: Int, height: Int, framesPerSecond: Int, durationFrames: Int) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
        self.durationFrames = durationFrames
    }

    /// Length in seconds; 0 when the frame rate is not positive.
    public var durationSeconds: Double {
        framesPerSecond > 0 ? Double(durationFrames) / Double(framesPerSecond) : 0
    }
}

public struct HaloProject: Sendable, Equatable {
    public private(set) var compositions: [HaloComposition] = []
    public private(set) var selectedCompositionID: String?

    public init() {}

    public var selectedComposition: HaloComposition? {
        compositions.first { $0.id == selectedCompositionID }
    }

    /// Adds a 1080p, 30 fps, 10 second composition named after its position
    /// and selects it.
    public mutating func newComposition() {
        let n = compositions.count + 1
        compositions.append(HaloComposition(
            id: "comp-\(n)", name: "Comp \(n)", width: 1920, height: 1080,
            framesPerSecond: 30, durationFrames: 300))
        selectedCompositionID = "comp-\(n)"
    }

    /// Selects a composition by id. An unknown id is ignored.
    public mutating func selectComposition(_ id: String) {
        if compositions.contains(where: { $0.id == id }) { selectedCompositionID = id }
    }
}
