// KeyframeFacing.swift: UC3 (SJ14), the stopwatch and diamond a keyframe button
// shows for idle, animated and keyed-here, with what VoiceOver reads, and
// FakeKeyframeFacing. Foundation only; verbatim from blueprint section 5.2.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum KeyPresence: Sendable, CaseIterable { case idle, animated, keyedHere }
public enum KeyAction: Sendable { case add, remove }

public struct KeyframeFace: Hashable, Sendable {
    public var symbol: String
    public var diamondSymbol: String?       // nil: the slot is reserved but empty
    public var diamondAction: KeyAction?
    public var spoken: String
    public init(symbol: String, diamondSymbol: String?, diamondAction: KeyAction?, spoken: String) {
        self.symbol = symbol; self.diamondSymbol = diamondSymbol; self.diamondAction = diamondAction; self.spoken = spoken
    }
}

public protocol KeyframeFacing: Sendable {
    func face(for presence: KeyPresence) -> KeyframeFace
}

public struct FakeKeyframeFacing: KeyframeFacing {
    public init() {}
    public func face(for presence: KeyPresence) -> KeyframeFace {
        switch presence {
        case .idle: KeyframeFace(symbol: "stopwatch", diamondSymbol: nil, diamondAction: nil, spoken: "Not animated")
        case .animated: KeyframeFace(symbol: "stopwatch.fill", diamondSymbol: "diamond", diamondAction: .add, spoken: "Animated")
        case .keyedHere: KeyframeFace(symbol: "stopwatch.fill", diamondSymbol: "diamond.fill", diamondAction: .remove, spoken: "Keyed at this frame")
        }
    }
}
