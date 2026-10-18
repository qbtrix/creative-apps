// SuiteTransport.swift: the transport capsule's live rule (UC13). A stub
// with its final signature until EC-5b of the editor-chrome packet fills it:
// today every call returns FakeTransportStepping's value. EC-5b gives it
// FlarePlayback's semantics (wrap while looping, else clamp; the
// seconds:frames timecode "00:12 / 02:00" and its tooltip, #1844). Foundation
// only.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteTransport: TransportStepping {
    public init() {}
    public func stepped(_ state: TransportState, by frames: Int) -> TransportState {
        FakeTransportStepping().stepped(state, by: frames)
    }
    public func toStart(_ state: TransportState) -> TransportState { FakeTransportStepping().toStart(state) }
    public func toEnd(_ state: TransportState) -> TransportState { FakeTransportStepping().toEnd(state) }
    public func face(_ state: TransportState) -> TransportFace { FakeTransportStepping().face(state) }
}
