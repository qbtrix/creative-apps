// EditorShellTests.swift: the plain math and values behind the editor shell
// parts: ruler ticks, canvas placement, zoom stops, hex colors, number
// formats, tool shortcuts in tooltips and the shell's fit in the window
// minimum. No SwiftUI rendering. macOS only.
import CoreGraphics
import SuiteUI
import Testing

@Test func rulerLabelsEveryHundredPixelsAtFullSize() {
    let ticks = RulerTicks(length: 500, origin: 0, scale: 1, minimumLabelSpacing: 64)
    #expect(ticks.step == 100)
    #expect(ticks.major.map(\.label) == ["0", "100", "200", "300", "400", "500"])
    #expect(ticks.major.map(\.position) == [0, 100, 200, 300, 400, 500])
    // A 100 step splits into ten minor ticks 10 points apart.
    #expect(ticks.minor.prefix(3) == [10, 20, 30])
}

@Test func rulerStepGrowsAsTheZoomShrinks() {
    #expect(RulerTicks(length: 800, origin: 0, scale: 0.25, minimumLabelSpacing: 64).step == 500)
    #expect(RulerTicks(length: 800, origin: 0, scale: 0.1, minimumLabelSpacing: 64).step == 1000)
    // Zoomed far in, the step never drops under one pixel.
    #expect(RulerTicks(length: 800, origin: 0, scale: 200, minimumLabelSpacing: 64).step == 1)
}

@Test func rulerFollowsTheOriginAndLabelsNegatives() {
    let ticks = RulerTicks(length: 300, origin: 150, scale: 1, minimumLabelSpacing: 64)
    #expect(ticks.major.map(\.label) == ["-100", "0", "100"])
    #expect(ticks.major.map(\.position) == [50, 150, 250])
    #expect(ticks.minor.allSatisfy { (0...300).contains($0) })
}

@Test func rulerWithANonsenseScaleDrawsNothing() {
    for scale in [0, -1, .nan, .infinity] {
        let ticks = RulerTicks(length: 300, origin: 0, scale: scale, minimumLabelSpacing: 64)
        #expect(ticks.major.isEmpty && ticks.minor.isEmpty)
    }
    let far = RulerTicks(length: 1e9, origin: 0, scale: 1e-9, minimumLabelSpacing: 0)
    #expect(far.major.count <= RulerTicks.maximumMarks)
}

@Test func canvasLayoutCentresAFittingDocument() {
    let layout = CanvasLayout(document: CGSize(width: 400, height: 300), zoom: 0.5, viewport: CGSize(width: 800, height: 600))
    #expect(layout.artboard == CGSize(width: 200, height: 150))
    #expect(layout.content == CGSize(width: 800, height: 600))
    #expect(layout.origin == CGPoint(x: 300, y: 225))
    #expect(layout.documentPoint(CGPoint(x: 300, y: 225)) == .zero)
    #expect(layout.documentPoint(CGPoint(x: 400, y: 275)) == CGPoint(x: 200, y: 100))
}

@Test func canvasLayoutScrollsALargeDocumentWithAMargin() {
    let layout = CanvasLayout(
        document: CGSize(width: 1000, height: 1000), zoom: 2, viewport: CGSize(width: 800, height: 600), margin: 32)
    #expect(layout.content == CGSize(width: 2064, height: 2064))
    #expect(layout.origin == CGPoint(x: 32, y: 32))
    #expect(layout.documentPoint(CGPoint(x: 34, y: 36)) == CGPoint(x: 1, y: 2))
}

@Test func canvasLayoutSurvivesABadZoomAndAnEmptyDocument() {
    let layout = CanvasLayout(document: .zero, zoom: .nan, viewport: CGSize(width: 100, height: 100))
    #expect(layout.scale == 1)
    #expect(layout.artboard == CGSize(width: 1, height: 1))
}

@Test func zoomStepsThroughTheStops() {
    #expect(ViewerZoom.zoomedIn(from: 1) == 1.5)
    #expect(ViewerZoom.zoomedOut(from: 1) == 2.0 / 3)
    #expect(ViewerZoom.zoomedIn(from: 0.42) == 0.5)
    #expect(ViewerZoom.zoomedOut(from: 0.42) == 1.0 / 3)
    #expect(ViewerZoom.zoomedIn(from: 32) == 32)
    #expect(ViewerZoom.zoomedOut(from: 0.05) == 0.05)
    #expect(ViewerZoom.zoomedIn(from: .nan) == 1)
}

@Test func hexColorReadsAndWritesCodes() {
    #expect(HexColor("#1877F2") == HexColor(0x18, 0x77, 0xF2))
    #expect(HexColor(" 1877f2 ") == HexColor(0x18, 0x77, 0xF2))
    #expect(HexColor("#f80") == HexColor(0xFF, 0x88, 0x00))
    #expect(HexColor(0x18, 0x07, 0xF2).text == "#1807F2")
    for bad in ["", "#", "#12345", "#1234567", "#GG0000", "##123456", "12 345"] {
        #expect(HexColor(bad) == nil, "\(bad) read as a color")
    }
}

@Test func hexColorRoundTripsThroughSwiftUIColor() {
    let blue = HexColor(0x18, 0x77, 0xF2)
    #expect(HexColor(.init(red: 0x18 / 255, green: 0x77 / 255, blue: 0xF2 / 255)) == blue)
    #expect(HexColor(.init(red: 2, green: -1, blue: 0.5)) == HexColor(255, 0, 128))
}

@Test func numbersShowTheFieldsDecimals() {
    #expect(NumericInput.format(60.39, decimals: 0) == "60")
    #expect(NumericInput.format(12.51, decimals: 1) == "12.5")
    #expect(NumericInput.format(0.25, decimals: 1) == "0.3")
    #expect(NumericInput.format(0.5, decimals: 0) == "1")
    #expect(NumericInput.format(-2.5, decimals: 0) == "-3")
    #expect(NumericInput.format(-0.04, decimals: 1) == "0")
    #expect(NumericInput.format(12.345) == "12.35")
}

@Test func toolTooltipsNameTheirShortcut() {
    #expect(ToolbarAction("Brush", systemImage: "paintbrush", shortcut: "b").help == "Brush (B)")
    #expect(ToolbarAction("Brush", systemImage: "paintbrush").help == "Brush")
    #expect(ToolbarAction("Crop", systemImage: "crop", unavailableHelp: "Not yet.", shortcut: "c").help == "Not yet.")
}

@Test func editorShellFitsTheWindowMinimum() {
    let rail = SuiteSize.toolButton + 2 * SuiteSpacing.xs
    let shell = rail + SuiteSize.contentMinimum.width + SuiteSize.editorPanelWidth
    #expect(shell <= SuiteSize.windowMinimum.width)
    #expect(SuiteSize.editorTopBar >= SuiteSize.toolButton)
}
