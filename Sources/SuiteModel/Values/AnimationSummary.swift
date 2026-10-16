// AnimationSummary.swift: what Halo shows about a Flare animation it places,
// read without opening the engine. Foundation free, Linux-safe, Sendable.

/// The size, timing and scenes of one Flare animation.
public struct AnimationSummary: Codable, Equatable, Sendable {
    public var name: String
    public var width: Double, height: Double
    public var framesPerSecond: Double
    public var frameCount: Int
    public var sceneNames: [String]
    public init(name: String, width: Double, height: Double, framesPerSecond: Double, frameCount: Int, sceneNames: [String]) {
        self.name = name; self.width = width; self.height = height
        self.framesPerSecond = framesPerSecond; self.frameCount = frameCount; self.sceneNames = sceneNames
    }
}
