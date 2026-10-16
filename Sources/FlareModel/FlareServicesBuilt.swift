// FlareServicesBuilt.swift: draw-key-save DK-3. `.built` is `.live` with the live type for every member whose live
// conformance has merged (stage, hits, shapes, properties, keyframes, easing, scenes) and `.live`'s `NotBuilt` for the
// rest. `.live` stays as it is so the fakes' tests keep their `NotBuilt` members; IN-9 #399 folds `.built` into it.
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
        return services
    }
}
