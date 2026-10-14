// HaloServices.swift (W0): one existential per Halo contract. HaloProject
// takes it at init; `.fake` runs the views on fakes, `.live` is what the app
// ships. W0 fills `.live` with `HaloNotBuilt`, which says why for every
// control; each feature swaps its own live type in by editing only its own
// Live/<Name>.swift file, because W0 already names `LiveFrameDrawing` and the
// rest here as typealiases of `HaloNotBuilt`.
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

    public init(
        drawing: any FrameDrawing, placing: any LayerPlacing, keying: any PropertyKeying,
        dragging: any ViewerDragging, easing: any KeyEasing, history: any ProjectHistory, files: any ProjectFiles,
        clock: any PlaybackClock, rendering: any FrameRendering, compositionRendering: any CompositionRendering
    ) {
        self.drawing = drawing; self.placing = placing; self.keying = keying; self.dragging = dragging
        self.easing = easing; self.history = history; self.files = files; self.clock = clock
        self.rendering = rendering; self.compositionRendering = compositionRendering
    }

    public static let fake = HaloServices(
        drawing: FakeFrameDrawing(), placing: FakeLayerPlacing(), keying: FakePropertyKeying(),
        dragging: FakeViewerDragging(), easing: FakeKeyEasing(), history: FakeProjectHistory(),
        files: FakeProjectFiles(), clock: FakePlaybackClock(), rendering: FakeFrameRendering(),
        compositionRendering: FakeCompositionRendering())

    public static let live = HaloServices(
        drawing: LiveFrameDrawing(), placing: LiveLayerPlacing(), keying: LivePropertyKeying(),
        dragging: LiveViewerDragging(), easing: LiveKeyEasing(), history: LiveProjectHistory(),
        files: LiveProjectFiles(), clock: LivePlaybackClock(), rendering: LiveFrameRendering(),
        compositionRendering: LiveCompositionRendering())
}
