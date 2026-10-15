// Live/LiveFrameDrawing.swift: the viewer's live FrameDrawing (#37). The
// draw list comes from HaloDrawRules, each layer placed by `placing`
// (LiveLayerPlacing unless a test passes another). Linux-safe.

public struct LiveFrameDrawing: FrameDrawing {
    private let placing: any LayerPlacing
    public init(placing: any LayerPlacing = LiveLayerPlacing()) { self.placing = placing }
    public var unavailableHelp: String? { nil }
    public func drawList(_ composition: HaloComposition, at frame: Int) -> HaloDrawList {
        HaloDrawRules.drawList(composition, at: frame, placing: placing)
    }
}
