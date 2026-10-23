// DesignTextHintSnapshots.swift: the "Zoom in to read text" hint (#3336) is a warning, not a
// selection fact. design.md (State colors) gives the text pills the warning tint, color and
// triangle, and keeps accent for selected or active, so the hint must not read as a second size
// badge. A "Hello" box edited at 43% shows the hint; the test counts pixels in stateWarning's ink
// in that canvas (the triangle and the text) against the same box at 100%, where no hint shows.
// macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignTextHintSnapshots {
    @Test(arguments: [ColorScheme.light, .dark])
    func theZoomHintDrawsAsAWarning(scheme: ColorScheme) throws {
        var model = DesignWorkspace()
        model.newFile()
        model.selectTool(.text)
        let click = DesignPoint(x: 300, y: 820)
        model.drag(from: click, to: click)
        model.endDrag()
        model.setTextDraft("Hello")
        #expect(model.textLegibilityHint(zoom: 0.43) != nil)
        #expect(model.textLegibilityHint(zoom: 1) == nil)
        let ink = SuitePalette.stateWarning
        let hex = scheme == .dark ? ink.dark : ink.light
        let small = try #require(render(DesignCanvas(model: model, zoom: 0.43), scheme: scheme))
        let full = try #require(render(DesignCanvas(model: model, zoom: 1), scheme: scheme))
        let hinted = pixels(near: hex, in: small)
        #expect(hinted >= 20, "the hint shows \(hinted) pixels of warning ink (\(scheme))")
        #expect(pixels(near: hex, in: full) < 5, "warning ink shows with no hint (\(scheme))")
    }

    /// How many pixels sit within a small sRGB distance of `hex`.
    private func pixels(near hex: UInt32, in image: NSBitmapImageRep) -> Int {
        let target = [Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF)]
        var count = 0
        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                guard let c = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let rgb = [c.redComponent, c.greenComponent, c.blueComponent].map { Double($0) * 255 }
                if zip(rgb, target).allSatisfy({ abs($0 - $1) <= 24 }) { count += 1 }
            }
        }
        return count
    }
}
#endif
