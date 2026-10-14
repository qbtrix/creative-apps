// FlareServices.swift: one existential per contract (docs/blueprints/flare.md, 6.3); `NotBuilt` until a fake lands.
import FlareCore

public struct FlareServices: Sendable {
    public var scenes: any SceneEditing
    public var stage: any StageRendering
    public var hits: any StageHitTesting
    public var shapes: any ShapeBuilding
    public var properties: any PropertyAnimating
    public var keyframes: any KeyframeEditing
    public var easing: any KeyframeEasing
    public var onion: any OnionSkinning
    public var library: any LibraryManaging
    public var machines: any StateMachineEditing
    public var preview: any StateMachinePreviewing
    public var export: any Exporting
    public var assist: any AnimationAssisting
    /// True while any member is a fake; drives the "Preview data" pill.
    public var isPreview: Bool

    public init(scenes: any SceneEditing, stage: any StageRendering, hits: any StageHitTesting, shapes: any ShapeBuilding,
                properties: any PropertyAnimating, keyframes: any KeyframeEditing, easing: any KeyframeEasing,
                onion: any OnionSkinning, library: any LibraryManaging, machines: any StateMachineEditing,
                preview: any StateMachinePreviewing, export: any Exporting, assist: any AnimationAssisting, isPreview: Bool) {
        self.scenes = scenes; self.stage = stage; self.hits = hits; self.shapes = shapes; self.properties = properties
        self.keyframes = keyframes; self.easing = easing; self.onion = onion; self.library = library
        self.machines = machines; self.preview = preview; self.export = export; self.assist = assist; self.isPreview = isPreview
    }

    /// Every member a fake. `assistMode` comes from `-FlareAssistMode` (read by LM-0c4's fake).
    public static func fake(assistMode: FakeAssistMode = .ok) -> FlareServices {
        FlareServices(
            scenes: FakeScenes(),
            stage: FakeStage(),
            hits: FakeHits(),
            shapes: FakeShapes(),
            properties: FakeProperties(),
            keyframes: FakeKeyframes(),
            easing: FakeEasing(),
            onion: FakeOnion(),
            library: FakeLibrary(),
            machines: FakeMachines(),
            preview: FakePreview(),
            export: FakeExport(),
            assist: NotBuilt(reason: "Not built yet (LM-0c4)."),
            isPreview: true)
    }

    /// Live members once integrated; each IN task swaps in one line here.
    public static var live: FlareServices {
        FlareServices(
            scenes: NotBuilt(reason: "Not connected yet (IN-4)."),
            stage: NotBuilt(reason: "Not connected yet (IN-1)."),
            hits: NotBuilt(reason: "Not connected yet (IN-1)."),
            shapes: NotBuilt(reason: "Not connected yet (IN-1)."),
            properties: NotBuilt(reason: "Not connected yet (IN-1)."),
            keyframes: NotBuilt(reason: "Not connected yet (IN-2)."),
            easing: NotBuilt(reason: "Not connected yet (IN-2)."),
            onion: NotBuilt(reason: "Not connected yet (IN-3)."),
            library: NotBuilt(reason: "Not connected yet (IN-5)."),
            machines: NotBuilt(reason: "Not connected yet (IN-6)."),
            preview: NotBuilt(reason: "Not connected yet (IN-6)."),
            export: NotBuilt(reason: "Not connected yet (IN-7)."),
            assist: NotBuilt(reason: "Assist needs the suite's model provider."),
            isPreview: true)
    }
}
