// Fakes/FakeFrameDrawing.swift: a small, predictable FrameDrawing (#37):
// HaloDrawRules with FakeLayerPlacing, so it shares the live rule.
// Linux-safe; never used by `.live`.

public struct FakeFrameDrawing: FrameDrawing {
    public init() {}
    public func drawList(_ composition: HaloComposition, at frame: Int) -> HaloDrawList {
        HaloDrawRules.drawList(composition, at: frame, placing: FakeLayerPlacing())
    }
}
