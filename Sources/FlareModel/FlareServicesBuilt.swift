// FlareServicesBuilt.swift: draw-key-save DK-3. `.built` is `.live` with the live type for every member whose live
// conformance has merged (stage, hits, shapes, properties, keyframes, easing, scenes, and export through
// `LiveExportAdapter` on its own `LiveStage`, flare-export FX-9) and `.live`'s `NotBuilt` for the rest. It holds no
// fakes, so `isPreview` is false: the export window then writes through `StageRasterizer` and `LiveMedia`, and the
// stage shows no "Preview data" pill. The beta hides the `NotBuilt` members' commands by id (`menuHidden`), not by
// `isPreview`. `.live` stays as it is so the fakes' tests keep their `NotBuilt` members; IN-9 #399 folds `.built` into it.
import FlareCore

extension FlareServices {
    /// What a launch without `-FlareFixture` runs on.
    public static var built: FlareServices {
        var services = FlareServices.live
        services.stage = LiveStage()
        services.hits = LiveHits()
        services.shapes = LiveShapes()
        services.properties = LiveProperties()
        services.keyframes = LiveKeyframes()
        services.easing = LiveEasing()
        services.scenes = LiveScenes()
        services.export = LiveExportAdapter(stage: LiveStage())
        services.isPreview = false
        return services
    }
}
