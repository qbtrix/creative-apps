// Live/LiveCompositionRendering.swift: the live CompositionRendering (#429).
// HaloRenderRules plans the files and runs the frame loop, each frame drawn
// by LiveFrameDrawing and rendered by LiveFrameRendering, the same pair
// Render Frame uses, so what the viewer shows is what the files hold.
// Linux-safe.

public struct LiveCompositionRendering: CompositionRendering {
    private let drawing: any FrameDrawing
    private let rendering: any FrameRendering
    public init(drawing: any FrameDrawing = LiveFrameDrawing(), rendering: any FrameRendering = LiveFrameRendering()) {
        self.drawing = drawing; self.rendering = rendering
    }
    public var unavailableHelp: String? { nil }
    public func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan {
        try HaloRenderRules.plan(composition, settings)
    }
    public func run(
        _ plan: HaloRenderPlan, of composition: HaloComposition, text: (any TextRasterizing)?,
        into sink: inout some RenderSink, isCancelled: () -> Bool
    ) -> HaloRenderOutcome {
        HaloRenderRules.run(
            plan, of: composition, text: text, drawing: drawing, rendering: rendering, into: &sink,
            isCancelled: isCancelled)
    }
}
