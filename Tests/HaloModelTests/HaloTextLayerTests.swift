// HaloTextLayerTests.swift (TX-1, #430): a text layer's words and size on
// `empty` with the fake services, whose FakeTextRasterizer measures 0.6 em a
// character by one em. Each commit is one named step ("Edit Text", "Change
// Text Size", a size scrub coalesced until `endTextSizeScrub`), a blank
// string is refused under the TEXT field and records nothing, and the stored
// box is the one `services.text.measure` gives (HF-10's Linux half). Runs on
// Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import HaloModel
import Testing

/// 50 px a character, 1.25 em tall: far from the estimate, so a stored
/// estimate can't pass for a measured box.
private struct WideMeasure: TextRasterizing {
    func measure(_ text: HaloTextContent) -> HaloLayerRect {
        HaloLayerRect(x: 0, y: 0, width: 50 * Double(text.string.count), height: 1.25 * text.fontSize)
    }
    func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer {
        try PixelBuffer(width: 1, height: 1)
    }
}

/// `empty` with a new text layer selected ("Text 1").
private func textProject(text: (any TextRasterizing)? = FakeTextRasterizer()) throws -> HaloProject {
    var services = HaloServices.fake
    services.text = text
    var project = HaloProject(services: services, document: try #require(HaloFixtures.project("empty")))
    project.newLayer(.text)
    return project
}

/// Whether the selected text's stored box is `width` x `height`, within
/// rounding (0.6 em x 5 characters at 72 is 215.99999999999997).
private func hasBox(_ project: HaloProject, _ width: Double, _ height: Double) -> Bool {
    guard let text = project.selectedText else { return false }
    return abs(text.width - width) < 1e-9 && abs(text.height - height) < 1e-9
}

@Test func newTextLayerReadsTextAt72() throws {
    let project = try textProject()
    #expect(project.selectedLayer?.name == "Text 1")
    #expect(project.selectedText?.string == "Text")
    #expect(project.selectedText?.fontSize == 72)
    #expect(project.selectedText?.sizeText == "72 px")
}

@Test func selectedTextIsNilWithoutATextLayer() throws {
    var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
    #expect(project.selectedText == nil)
    project.newLayer(.solid)
    #expect(project.selectedText == nil)
    project.setText("Hello")
    project.setFontSize(96)
    #expect(project.selectedLayer?.text == nil)
    #expect(project.undoTitle == "Undo New Layer")
}

@Test func setTextStoresTheMeasuredBoxAsOneStep() throws {
    var project = try textProject()
    let steps = project.history.undo.count
    project.setText("Hello")
    #expect(project.selectedText?.string == "Hello")
    #expect(hasBox(project, 216, 72))
    #expect(project.history.undo.count == steps + 1)
    #expect(project.undoTitle == "Undo Edit Text")
    #expect(project.viewerSummary == "Frame 0: Text 1: Hello")
    #expect(project.refusal == nil)
}

@Test func setFontSizeStoresTheMeasuredBoxAndCentersIt() throws {
    var project = try textProject()
    project.setText("Hello")
    project.setFontSize(96)
    #expect(project.selectedText?.fontSize == 96)
    #expect(project.selectedText?.sizeText == "96 px")
    #expect(hasBox(project, 288, 96))
    #expect(project.undoTitle == "Undo Change Text Size")
    let comp = try #require(project.selectedComposition)
    let bounds = try #require(project.selectedLayer).bounds(in: comp)
    #expect(bounds == HaloLayerRect(x: 816, y: 492, width: 288, height: 96))
}

@Test(arguments: ["", "   ", "\n"])
func blankTextIsRefusedAndRecordsNothing(_ blank: String) throws {
    var project = try textProject()
    project.setText("Hello")
    let before = project.history
    project.setText(blank)
    #expect(project.refusal == HaloRefusal(control: "halo.inspector.text.string", message: "Enter some text."))
    #expect(project.selectedText?.string == "Hello")
    #expect(project.history == before)
}

@Test func theSameTextRecordsNothing() throws {
    var project = try textProject()
    project.setText("Hello")
    let before = project.history
    project.setText("Hello")
    #expect(project.history == before)
}

@Test func newlinesBecomeSpaces() throws {
    var project = try textProject()
    project.setText("A\nB")
    #expect(project.selectedText?.string == "A B")
    project.setText("C\r\nD")
    #expect(project.selectedText?.string == "C D")
}

@Test func eachCommitIsOneNamedStep() throws {
    var project = try textProject()
    let start = project.history.undo.count
    project.setText("Hello")
    #expect(project.history.undo.count == start + 1)
    #expect(project.history.undo.last?.name == "Edit Text")
    project.setFontSize(80)
    project.setFontSize(90)
    project.setFontSize(96)
    project.endTextSizeScrub()
    #expect(project.history.undo.count == start + 2)
    #expect(project.history.undo.last?.name == "Change Text Size")
    project.setFontSize(100)
    #expect(project.history.undo.count == start + 3)
    project.undo()
    #expect(project.selectedText?.fontSize == 96)
    project.undo()
    #expect(project.selectedText?.fontSize == 72)
    #expect(project.selectedText?.string == "Hello")
}

@Test func sizeClampsAndIgnoresNaN() throws {
    var project = try textProject()
    project.setFontSize(0)
    #expect(project.selectedText?.fontSize == 1)
    project.setFontSize(5000)
    #expect(project.selectedText?.fontSize == 1000)
    project.endTextSizeScrub()
    let before = project.document
    let history = project.history
    project.setFontSize(.nan)
    project.setFontSize(.infinity)
    #expect(project.document == before)
    #expect(project.history == history)
}

@Test func sizeTextShowsTenthsOnlyWhenNeeded() {
    #expect(HaloTextContent(fontSize: 96).sizeText == "96 px")
    #expect(HaloTextContent(fontSize: 72.5).sizeText == "72.5 px")
    #expect(HaloTextContent(fontSize: .nan).sizeText == "–")
    #expect(HaloTextContent.fontSizeRange == 1...1000)
}

@Test func undoAndRedoWalkTextThenSize() throws {
    var project = try textProject()
    project.setText("Hello")
    project.setFontSize(96)
    project.undo()
    project.undo()
    #expect(project.selectedText?.string == "Text")
    #expect(project.selectedText?.fontSize == 72)
    project.redo()
    #expect(project.selectedText?.string == "Hello")
    #expect(project.selectedText?.fontSize == 72)
}

@Test func storedBoxEqualsMeasure() throws {
    var wide = try textProject(text: WideMeasure())
    wide.setText("Hello")
    #expect(hasBox(wide, 250, 90))
    wide.setFontSize(96)
    #expect(hasBox(wide, 250, 120))

    var estimate = try textProject(text: nil)
    estimate.setText("Hello")
    #expect(hasBox(estimate, 216, 72))
}

@Test func textSizeAndBoxSurviveAFile() throws {
    var project = try textProject()
    project.setText("Hello")
    project.setFontSize(96)
    let decoded = try project.services.files.decode(project.fileData())
    project.beginOpen(name: "Spot", path: "/t/Spot.halo")
    project.finishOpen(.success(decoded))
    let text = try #require(project.selectedComposition?.layers.first?.text)
    #expect(text == HaloTextContent(string: "Hello", fontSize: 96, width: 288, height: 96))
}

@Test func renderedFrameFillsTheStoredBox() throws {
    var project = try textProject()
    project.setText("Hello")
    project.setFontSize(96)
    let comp = try #require(project.selectedComposition)
    let list = project.services.drawing.drawList(comp, at: 0)
    let frame = try LiveFrameRendering().render(list, width: 1920, height: 1080, text: FakeTextRasterizer())
    let inside = try frame.pixels.pixel(x: 960, y: 540)
    let ink = try #require(project.selectedLayerColor)  // FakeTextRasterizer fills with the raw components
    #expect(inside == RGBA(r: Float(ink.red), g: Float(ink.green), b: Float(ink.blue), a: 1))
    #expect(try frame.pixels.pixel(x: 810, y: 540).a == 0)
}
