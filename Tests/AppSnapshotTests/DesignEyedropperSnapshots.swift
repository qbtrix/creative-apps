// DesignEyedropperSnapshots.swift (eyedropper DY-4): the Eyedropper's loupe over a two-shape design. A new file
// with a rectangle and an ellipse drawn on its Desktop frame, the Eyedropper active and the pointer resting on
// the ellipse: the loupe rings the pointer with the colour under it and its hex ("No colour here" until DY-5's
// adapter bodies read the document), the size chips at the artboard's top left. The hover store is bound for the
// render, so the app's shared one is never touched. Writes design-eyedropper-loupe-light.png and -dark.png.
// `sizeChipsFit` checks that the floating chips give every label its full width with room to spare, and
// `onChipReadsOverWhite` that the chosen chip's label reads over a white artboard in Dark.
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignEyedropperSnapshots {
    @Test func loupe() throws {
        var model = DesignWorkspace()
        model.newFile()
        drawOnCanvas(&model, .rectangle, from: (160, 160), to: (640, 480))
        drawOnCanvas(&model, .ellipse, from: (560, 300), to: (960, 700))
        model.deselect()
        model.selectTool(.eyedropper)
        let store = DesignCanvasHover()
        store.record(DesignPoint(x: 760, y: 500), modifiers: [], on: model)
        #expect(store.loupe(for: model)?.point == DesignPoint(x: 760, y: 500))
        try DesignCanvasHover.$bound.withValue(store) {
            try shootCanvas(model, "design-eyedropper-loupe")
        }
    }

    /// The size chips float on the canvas with no column around them, so their own width must fit "Point" with room to
    /// spare: at their bare fitting width (#3816) a 1x render rounds the label over and shows "Poi…".
    @Test func sizeChipsFit() {
        let label = NSHostingView(rootView: Text("Point").font(SuiteFont.caption.weight(.semibold)).fixedSize())
        let chip = label.fittingSize.width + 2 * SuiteSpacing.xs
        let row = NSHostingView(rootView: DesignSampleLoupe.sizeChips(.point) { _ in }).fittingSize.width
        let spare = 3 * SuiteSpacing.xs
        #expect(row >= 3 * chip + 2 * SuiteSpacing.xs + spare, "the chips are \(row) pt wide; Point needs \(chip) pt a chip")
    }

    /// The chips float over the artwork, so in Dark the chosen chip's label must still read on a white artboard: the
    /// strongest contrast inside the Point chip, around its label, is at least 3:1.
    @Test func onChipReadsOverWhite() throws {
        let chips = DesignSampleLoupe.sizeChips(.point) { _ in }
        let size = NSHostingView(rootView: chips).fittingSize
        let image = try #require(render(
            chips.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(.white),
            scheme: .dark))
        // The chips fill SuiteSize.inspectorWidth.min, centred in whatever backing pads them.
        let chip = (SuiteSize.inspectorWidth.min - 2 * SuiteSpacing.xs) / 3
        let x = Int((size.width - SuiteSize.inspectorWidth.min) / 2 + chip / 2), y = Int(size.height / 2)
        var lumas: [Double] = []
        for dx in -14...14 { for dy in -4...4 { lumas.append(luminance(image, x + dx, y + dy)) } }
        let ratio = ((lumas.max() ?? 0) + 0.05) / ((lumas.min() ?? 0) + 0.05)
        #expect(ratio >= 3, "the Point chip's label reads at \(ratio):1 over white in Dark")
    }
}

/// WCAG relative luminance of the sRGB pixel at (x, y), top-left origin; 0 off the image.
@MainActor
private func luminance(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) -> Double {
    guard let c = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return 0 }
    let channel = { (v: CGFloat) in v <= 0.04045 ? Double(v) / 12.92 : pow((Double(v) + 0.055) / 1.055, 2.4) }
    return 0.2126 * channel(c.redComponent) + 0.7152 * channel(c.greenComponent) + 0.0722 * channel(c.blueComponent)
}
