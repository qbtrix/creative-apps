// LayerRefusalMessageTests.swift: a refused layer or timeline edit says why in plain words (#800). A service that
// is not built yet shows its own reason, an engine refusal reads the same sentence Machines shows, and a sentence a
// fake wrote for a person passes through while engine text never does.
import FlareCore
@testable import FlareModel
import Testing

@Test func notBuiltReasonReachesThePerson() {
    let reason = "Scenes aren't available yet."
    var services = FlareServices.fake()
    services.scenes = FakeScenes(unavailable: reason)
    var w = FlareWorkspace(services: services)
    w.load(FlareFixtures.bounce)
    w.addScene()
    #expect(w.layerError?.message == reason)
    #expect(w.document == FlareFixtures.bounce)
}

@Test func engineRefusalsGiveTheirCause() {
    #expect(FlareLayerError.command(.frameOccupied(property: "x", frame: 5)).message
        == "That frame already has a keyframe.")
    #expect(FlareLayerError.command(.symbolInUse("star")).message == "An instance still uses that symbol.")
}

@Test func aFakesSentenceForAPersonPassesThrough() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    w.selectLayer("ball")
    w.setProperty("rotation", to: .nan, dragStart: 0)
    #expect(w.layerError?.message == "Rotation needs a number.")
    #expect(w.document == FlareFixtures.bounce)
}

@Test func engineTextNeverReachesThePerson() {
    let message = FlareLayerError.command(.invalidDocument("scene scene-1: canvas size must be finite and > 0")).message
    #expect(message == "That change could not be made.")
    #expect(!message.contains("scene-1"))
    #expect(FlareLayerError.command(.invalidDocument("Add State: invalid(\"x\")")).message
        == "That change could not be made.")
}
