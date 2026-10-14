// LockedLayerDrawingTests.swift: with a locked layer selected, Ellipse, Rectangle and Pen agree, in a scene and inside
// an edited symbol (#676): each is disabled with "Unlock <layer> to draw on it." as its help, a drag refuses with that
// text and adds nothing, and no refusal shows the raw `layerLocked(...)` debug text.
import FlareCore
@testable import FlareModel
import Testing

private let drawingTools: [FlareTool] = [.ellipse, .rectangle, .pen]

/// Bounce with its locked Background selected, or Wave edited in place with Hand locked and selected.
private func onALockedLayer(_ tool: FlareTool, inSymbol: Bool) -> (FlareWorkspace, name: String) {
    var w = FlareWorkspace(services: .fake())
    if inSymbol {
        w.load(FlareFixtures.character)
        w.editSymbol("wave")
        w.toggleLayerFlag("hand", .locked)
        w.selectLayer("hand")
    } else {
        w.load(FlareFixtures.bounce)
        w.selectLayer("background")
    }
    w.selectTool(tool)
    return (w, inSymbol ? "Hand" : "Background")
}

private func draw(_ tool: FlareTool, on w: inout FlareWorkspace) {
    if tool == .pen {
        for (x, y) in [(0.0, 0.0), (50, 0), (50, 50), (0, 0)] { w.drag(from: Point(x: x, y: y), to: Point(x: x, y: y)) }
    } else {
        w.drag(from: Point(x: 10, y: 10), to: Point(x: 60, y: 50))
    }
}

@Test(arguments: drawingTools, [false, true])
func aDrawingToolOnALockedLayerIsDisabledWithTheUnlockReason(tool: FlareTool, inSymbol: Bool) {
    let (w, name) = onALockedLayer(tool, inSymbol: inSymbol)
    #expect(w.layers.first { $0.id == w.selectedLayerID }?.isLocked == true)
    #expect(w.toolHelp(tool) == FlareWorkspace.unlockMessage(name))
}

@Test(arguments: drawingTools, [false, true])
func aDrawingToolOnALockedLayerAddsNothingAndSaysWhy(tool: FlareTool, inSymbol: Bool) {
    var (w, name) = onALockedLayer(tool, inSymbol: inSymbol)
    let document = w.document, canUndo = w.canUndo
    draw(tool, on: &w)
    #expect(w.document == document && w.canUndo == canUndo)
    #expect(w.layerError?.message == FlareWorkspace.unlockMessage(name))
    #expect(w.draft == nil)
}

@Test(arguments: drawingTools)
func unlockingTheLayerEnablesTheToolAgain(tool: FlareTool) {
    var (w, _) = onALockedLayer(tool, inSymbol: false)
    w.toggleLayerFlag("background", .locked)
    #expect(w.toolHelp(tool) == nil)
    draw(tool, on: &w)
    #expect(w.layerError == nil && w.layers.count == 4)
}

@Test func aLockedLayerErrorFromTheEngineReadsAsPlainWords() {
    let message = FlareLayerError.command(.layerLocked("background")).message
    #expect(!message.contains("layerLocked") && !message.contains("background"))
}
