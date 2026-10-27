// CanvasZoomLevelTests.swift: the zoom level a canvas host keeps instead of its own fit bookkeeping
// (#5070). `ZoomMath.scale` draws a level against the viewport: fit follows the viewport (so a window
// that settles keeps the picture fitted, until the user picks another level), 100% is 1, a scale is
// itself, all clamped to 10%...3200%. `EditorDetailLayout.paletteFit` is the palette-clear fit every
// editor window hands it. No SwiftUI rendering. macOS only.
import CoreGraphics
import SuiteKernel
import SuiteUI
import Testing

@Test func aFitLevelFollowsTheViewportAndTheOthersDoNot() {
    let document = CGSize(width: 2000, height: 1000)
    let small = CGSize(width: 1064, height: 664), large = CGSize(width: 2064, height: 1064)
    #expect(ZoomMath.scale(.fit, document: document, in: small, using: nil) == ZoomMath.fit(document: document, in: small))
    #expect(ZoomMath.scale(.fit, document: document, in: large, using: nil) == ZoomMath.fit(document: document, in: large))
    #expect(ZoomMath.scale(.fit, document: document, in: small, using: nil) != ZoomMath.scale(.fit, document: document, in: large, using: nil))
    #expect(ZoomMath.scale(.actual, document: document, in: small, using: nil) == 1)
    #expect(ZoomMath.scale(.scale(3), document: document, in: large, using: nil) == 3)
}

@Test func aLevelIsClampedAndAViewportWithNoRoomFitsAtTheSmallestZoom() {
    let document = CGSize(width: 800, height: 600)
    #expect(ZoomMath.scale(.scale(80), document: document, in: CGSize(width: 900, height: 700), using: nil) == 32)
    #expect(ZoomMath.scale(.scale(.nan), document: document, in: .zero, using: nil) == 0.1)
    #expect(ZoomMath.scale(.fit, document: document, in: .zero, using: nil) == 0.1)
}

@Test func theFitUsesTheHostsPaletteFitWhenItHasOne() {
    let document = CGSize(width: 1000, height: 1000), viewport = CGSize(width: 900, height: 1200)
    let paletteFit = EditorDetailLayout.paletteFit(toolCount: 8)
    let expected = EditorDetailLayout(viewport: viewport, toolCount: 8).fitScale(artboard: document)
    #expect(paletteFit(viewport, document) == expected)
    #expect(ZoomMath.scale(.fit, document: document, in: viewport, using: paletteFit) == expected)
    // The palette takes room at the sides, so a tall viewport fits tighter than the plain fit.
    #expect(expected < ZoomMath.fit(document: document, in: viewport))
}
