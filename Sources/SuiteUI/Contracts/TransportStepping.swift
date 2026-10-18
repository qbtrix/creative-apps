// TransportStepping.swift: UC13 (SJ5), what the transport capsule's buttons do
// to a TransportState and what the capsule reads, and FakeTransportStepping,
// which never wraps and prints frames instead of a timecode on purpose (the
// live rule wraps while looping and reads seconds:frames). Foundation only;
// verbatim from docs/blueprints/suiteui/contracts/Contracts.swift with the
// editor-chrome packet's one widening: TransportFace gains `timecodeHelp`,
// the timecode's tooltip (Flare's #1844), defaulting to nil so the Fake is
// unchanged. The live rule is EC-5b's SuiteTransport.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct TransportState: Hashable, Sendable {
    public var frame: Int
    /// How many frames: frames run 0...frameCount - 1, the same frames as a TimelineScale
    /// whose lastFrame is frameCount - 1. 0 means nothing to play.
    public var frameCount: Int
    public var fps: Int
    public var isPlaying: Bool
    public var loops: Bool
    public init(frame: Int, frameCount: Int, fps: Int, isPlaying: Bool = false, loops: Bool = false) {
        self.frame = frame; self.frameCount = frameCount; self.fps = fps; self.isPlaying = isPlaying; self.loops = loops
    }
}

public struct TransportFace: Hashable, Sendable {
    public var playTitle: String              // "Play" or "Pause"
    public var unavailableHelp: String?       // every button's reason when nothing can play
    public var timecode: String               // "00:01 / 00:02"
    public var timecodeHelp: String?          // the timecode's tooltip; nil when nothing can play
    public init(playTitle: String, unavailableHelp: String?, timecode: String, timecodeHelp: String? = nil) {
        self.playTitle = playTitle; self.unavailableHelp = unavailableHelp; self.timecode = timecode
        self.timecodeHelp = timecodeHelp
    }
}

public protocol TransportStepping: Sendable {
    /// Step `by` frames: stop at the ends, or wrap while `loops`.
    func stepped(_ state: TransportState, by frames: Int) -> TransportState
    func toStart(_ state: TransportState) -> TransportState
    func toEnd(_ state: TransportState) -> TransportState
    func face(_ state: TransportState) -> TransportFace
}

/// Never wraps and prints frames ("12 / 48") instead of a timecode.
public struct FakeTransportStepping: TransportStepping {
    public init() {}
    private func last(_ s: TransportState) -> Int { max(s.frameCount - 1, 0) }
    public func stepped(_ s: TransportState, by frames: Int) -> TransportState {
        var n = s; n.frame = min(max(s.frame + frames, 0), last(s)); return n
    }
    public func toStart(_ s: TransportState) -> TransportState { var n = s; n.frame = 0; return n }
    public func toEnd(_ s: TransportState) -> TransportState { var n = s; n.frame = last(s); return n }
    public func face(_ s: TransportState) -> TransportFace {
        TransportFace(playTitle: s.isPlaying ? "Pause" : "Play",
                      unavailableHelp: s.frameCount > 0 ? nil : "Nothing to play.",
                      timecode: "\(s.frame) / \(s.frameCount)")
    }
}
