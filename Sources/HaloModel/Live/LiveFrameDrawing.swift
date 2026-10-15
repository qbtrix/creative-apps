// Live/LiveFrameDrawing.swift: the W0 stub of the viewer's FrameDrawing.
// It draws nothing and says why; the viewer feature (#37) replaces this file
// whole with the live type. Linux-safe.

public struct LiveFrameDrawing: FrameDrawing {
    public init() {}
    public var unavailableHelp: String? { "Layers don't draw in the viewer yet (#37)." }
    public func drawList(_ composition: HaloComposition, at frame: Int) -> HaloDrawList {
        HaloDrawList(width: composition.width, height: composition.height, frame: frame, items: [])
    }
}
