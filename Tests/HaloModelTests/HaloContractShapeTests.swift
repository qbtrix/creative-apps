// HaloContractShapeTests.swift: the Halo contracts' shape: a service that
// works says nothing (`unavailableHelp` is nil by default), and every
// protocol can be held as an existential, as HaloServices holds them. Runs on
// Linux and macOS.
import HaloModel
import Testing

private struct PlainService: HaloService {}

private struct StubbedService: HaloService {
    var unavailableHelp: String? { "Not built yet (#37)." }
}

private struct EmptyDrawing: FrameDrawing {
    func drawList(_ composition: HaloComposition, at frame: Int) -> HaloDrawList {
        HaloDrawList(width: composition.width, height: composition.height, frame: frame, items: [])
    }
}

/// One slot per contract, as HaloServices declares them.
private struct Slots {
    var drawing: (any FrameDrawing)?
    var placing: (any LayerPlacing)?
    var keying: (any PropertyKeying)?
    var dragging: (any ViewerDragging)?
    var easing: (any KeyEasing)?
    var history: (any ProjectHistory)?
    var files: (any ProjectFiles)?
    var clock: (any PlaybackClock)?
    var rendering: (any FrameRendering)?
    var compositionRendering: (any CompositionRendering)?
    var text: (any TextRasterizing)?
    var sink: (any RenderSink)?
}

@Test func aServiceThatWorksHasNoHelpByDefault() {
    #expect(PlainService().unavailableHelp == nil)
    #expect(StubbedService().unavailableHelp == "Not built yet (#37).")
    let held: any HaloService = PlainService()
    #expect(held.unavailableHelp == nil)
}

@Test func everyContractIsHeldAsAnExistential() {
    var slots = Slots()
    #expect(slots.placing == nil && slots.keying == nil && slots.dragging == nil && slots.easing == nil)
    #expect(slots.history == nil && slots.files == nil && slots.clock == nil && slots.rendering == nil)
    #expect(slots.compositionRendering == nil && slots.text == nil && slots.sink == nil)
    slots.drawing = EmptyDrawing()
    let comp = HaloComposition(id: "comp-1", name: "Comp 1", width: 64, height: 32, framesPerSecond: 24, durationFrames: 48)
    let list = slots.drawing?.drawList(comp, at: 5)
    #expect(list == HaloDrawList(width: 64, height: 32, frame: 5, items: []))
    #expect(slots.drawing?.unavailableHelp == nil)
}
