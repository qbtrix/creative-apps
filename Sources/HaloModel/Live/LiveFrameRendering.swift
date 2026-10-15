// Live/LiveFrameRendering.swift: the W0 stub of FrameRendering. Rendering
// throws `.notBuilt`; the render feature (#451) replaces this file whole with
// the live type. Linux-safe.

public struct LiveFrameRendering: FrameRendering {
    public init() {}
    public var unavailableHelp: String? { "Render Frame arrives with #451." }
    public func render(_ list: HaloDrawList, width: Int, height: Int, text: (any TextRasterizing)?) throws -> HaloRenderedFrame {
        throw HaloEditError.notBuilt("Rendering")
    }
}
