// HaloServices.swift (W0): one existential per Halo contract. HaloProject
// takes it at init; `.fake` runs the views on fakes, `.live` is what the app
// ships. W0 already names `LiveFrameDrawing` and the rest here, each a stub
// struct in its own Live/<Name>.swift that says why its controls are
// disabled; a feature swaps its live type in by replacing only that file.
// `text` is the one service HaloApp supplies (CoreText); the Model can't.
public struct HaloServices: Sendable {
    public var drawing: any FrameDrawing
    public var placing: any LayerPlacing
    public var keying: any PropertyKeying
    public var dragging: any ViewerDragging
    public var easing: any KeyEasing
    public var history: any ProjectHistory
    public var files: any ProjectFiles
    public var clock: any PlaybackClock
    public var rendering: any FrameRendering
    public var compositionRendering: any CompositionRendering
    /// Draws and measures text layers; nil until HaloApp sets it at launch
    /// (HaloLaunch), so Linux tests run with the fake or without text.
    public var text: (any TextRasterizing)?

    public init(
        drawing: any FrameDrawing, placing: any LayerPlacing, keying: any PropertyKeying,
        dragging: any ViewerDragging, easing: any KeyEasing, history: any ProjectHistory, files: any ProjectFiles,
        clock: any PlaybackClock, rendering: any FrameRendering, compositionRendering: any CompositionRendering,
        text: (any TextRasterizing)? = nil
    ) {
        self.drawing = drawing; self.placing = placing; self.keying = keying; self.dragging = dragging
        self.easing = easing; self.history = history; self.files = files; self.clock = clock
        self.rendering = rendering; self.compositionRendering = compositionRendering; self.text = text
    }

    public static let fake = HaloServices(
        drawing: FakeFrameDrawing(), placing: FakeLayerPlacing(), keying: FakePropertyKeying(),
        dragging: FakeViewerDragging(), easing: FakeKeyEasing(), history: FakeProjectHistory(),
        files: FakeProjectFiles(), clock: FakePlaybackClock(), rendering: FakeFrameRendering(),
        compositionRendering: FakeCompositionRendering(), text: FakeTextRasterizer())

    public static let live = HaloServices(
        drawing: LiveFrameDrawing(), placing: LiveLayerPlacing(), keying: LivePropertyKeying(),
        dragging: LiveViewerDragging(), easing: LiveKeyEasing(), history: LiveProjectHistory(),
        files: LiveProjectFiles(), clock: LivePlaybackClock(), rendering: LiveFrameRendering(),
        compositionRendering: LiveCompositionRendering())
}
