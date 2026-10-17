// FlareInspectorTextTests.swift: the Properties tab's words, built in the Model. The scene header reads the
// stage's px like the ruler corner (#1846), and the empty state with no animation open says to create or open
// one rather than select a scene that doesn't exist (#1848).
import FlareModel
import Testing

@Test func sceneSummaryUsesTheStagesPixels() {
    let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
    #expect(model.sceneSummary == "550 × 400 px · 24 fps")
    #expect(model.sceneSizeText == "550 × 400 px")
    #expect(model.sceneRateText == "24 fps")
}

@Test func sceneTextIsNilWithNoDocument() {
    let model = FlareWorkspace()
    #expect(model.sceneSummary == nil && model.sceneSizeText == nil && model.sceneRateText == nil)
}

@Test func emptyInspectorWithNoDocumentSaysCreateOrOpen() {
    let empty = FlareWorkspace().inspectorEmptyText
    #expect(empty.title == "No Animation")
    #expect(empty.message.contains("Create or open an animation"))
    #expect(!empty.message.contains("Select a scene"))
}

@Test func emptyInspectorWithADocumentSaysSelectAScene() {
    let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
    #expect(model.document != nil)
    #expect(model.inspectorEmptyText.message == "Select a scene to see its properties.")
}
