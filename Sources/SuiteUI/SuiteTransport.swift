// SuiteTransport.swift: the transport capsule's live rule (UC13), declared
// with its final signature so TransportCapsule (EC-5a) and the gallery's
// editor page compile against it. A stub for now: it returns
// FakeTransportStepping's values (no wrap, frames instead of a timecode, no
// timecode tooltip). EC-5b fills the body with Flare's semantics: wrap while
// looping, else clamp, and a seconds:frames timecode with its tooltip. The
// state owners stay FlarePlayback and HaloPlayback; this is the face rule.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteTransport: TransportStepping {
    private let stub = FakeTransportStepping()

    public init() {}

    public func stepped(_ state: TransportState, by frames: Int) -> TransportState { stub.stepped(state, by: frames) }

    public func toStart(_ state: TransportState) -> TransportState { stub.toStart(state) }

    public func toEnd(_ state: TransportState) -> TransportState { stub.toEnd(state) }

    public func face(_ state: TransportState) -> TransportFace { stub.face(state) }
}
