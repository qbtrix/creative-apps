// EditorDetailLayoutTests.swift: EditorDetail's palette and fit math
// (EditorDetailLayout) across the detail columns a 1024 x 768 display gives a
// SuiteWindow (about 1024 x 737 inside the menu bar) with the editor's 304 pt
// inspector shown and hidden, and the window minimum, for wide, tall, tiny and
// huge artboards: the palette clear of the rulers, a fitted artboard's handles
// clear of the palette, the 5% clamp, and no zero, NaN or infinite zoom for
// degenerate sizes. Also Command-0's choice between the host's fit and
// ZoomMath's. No SwiftUI rendering. macOS only.
import CoreGraphics
import SuiteUI
import Testing

/// The window chrome above and below the detail's canvas region: the
/// toolbar and the status line. Assumed, not measured; the journeys measure.
private let toolbarHeight: CGFloat = 52
private let statusHeight: CGFloat = 28
private let editorInspector = SuiteSize.editorPanelWidth + 2 * SuiteSpacing.m

/// The viewport (inside the rulers) of a detail column `width` wide in a window `height` tall.
private func viewport(width: CGFloat, windowHeight: CGFloat) -> CGSize {
    CGSize(
        width: width - SuiteSize.ruler,
        height: windowHeight - toolbarHeight - statusHeight - SuiteSize.ruler)
}

private let viewports: [(String, CGSize)] = [
    ("1024 with inspector", viewport(width: 1024 - SuiteSize.sidebarWidth.ideal - editorInspector, windowHeight: 737)),
    ("1024 without inspector", viewport(width: 1024 - SuiteSize.sidebarWidth.ideal, windowHeight: 737)),
    ("window minimum", viewport(width: SuiteSize.contentMinimum.width, windowHeight: SuiteSize.windowMinimum.height)),
]
private let artboards = [
    CGSize(width: 1600, height: 1000), CGSize(width: 1000, height: 1600), CGSize(width: 1, height: 1),
    CGSize(width: 20000, height: 20000),
]
private let toolCounts = [1, 6, 10]
private let smallestZoom = 0.05

/// The fit before the clamp, as the packet's pseudocode writes it.
private func unclamped(_ layout: EditorDetailLayout, _ artboard: CGSize) -> Double {
    let horizontal = (layout.viewport.width - 2 * layout.clearance) / artboard.width
    let vertical = (layout.viewport.height - 2 * SuiteSpacing.xxl) / artboard.height
    return Double(min(horizontal, vertical))
}

@Test func editorDetailPaletteSizeIsOneButtonWideAndOnePerToolHigh() {
    #expect(EditorDetailLayout.paletteSize(toolCount: 6) == CGSize(width: 40, height: 6 * 32 + 8))
    #expect(EditorDetailLayout.paletteSize(toolCount: 0) == CGSize(width: 40, height: 8))
    #expect(EditorDetailLayout.paletteSize(toolCount: -3) == EditorDetailLayout.paletteSize(toolCount: 0))
    for count in toolCounts {
        let height = EditorDetailLayout.paletteSize(toolCount: count).height
        #expect(EditorDetailLayout.toolCount(paletteHeight: height) == count)
    }
    #expect(EditorDetailLayout.toolCount(paletteHeight: 0) == 0)
    #expect(EditorDetailLayout.toolCount(paletteHeight: .nan) == 0)
}

@Test func editorDetailPaletteClearsTheRulers() {
    for (name, size) in viewports {
        for count in toolCounts {
            let frame = EditorDetailLayout(viewport: size, toolCount: count).paletteFrame
            // In the detail's coordinates the viewport starts one ruler in on both axes.
            #expect(frame.minX + SuiteSize.ruler >= SuiteSize.ruler + SuiteSpacing.l, "\(name), \(count) tools")
            #expect(frame.minY + SuiteSize.ruler >= SuiteSize.ruler, "\(name), \(count) tools")
            #expect(frame.maxY <= size.height, "\(name), \(count) tools")
            #expect(abs(frame.midY - size.height / 2) < 0.001, "\(name), \(count) tools: centred")
        }
    }
}

@Test func editorDetailClearanceIsInsetPalettePlusHalfAHandle() {
    let layout = EditorDetailLayout(viewport: CGSize(width: 800, height: 600), toolCount: 6)
    #expect(layout.clearance == SuiteSpacing.l + 40 + SuiteSize.anchorHit / 2 + SuiteSpacing.xs)
}

@Test func editorDetailFittedArtboardHandlesStayClearOfThePalette() {
    for (name, size) in viewports {
        for count in toolCounts {
            let layout = EditorDetailLayout(viewport: size, toolCount: count)
            for artboard in artboards {
                let label = "\(name), \(count) tools, \(artboard.width)x\(artboard.height)"
                let scale = layout.fitScale(artboard: artboard)
                #expect(scale.isFinite && scale > 0, "\(label)")
                if unclamped(layout, artboard) >= smallestZoom {
                    let width = artboard.width * scale
                    // Centred, then grown by half a handle's hit on every side.
                    let leading = (size.width - width) / 2 - SuiteSize.anchorHit / 2
                    #expect(leading - layout.paletteFrame.maxX >= SuiteSpacing.xs - 1e-9, "\(label)")
                    #expect((size.height - artboard.height * scale) / 2 >= SuiteSpacing.xxl - 1e-9, "\(label)")
                } else {
                    #expect(scale == smallestZoom, "\(label)")
                }
            }
        }
    }
}

@Test func editorDetailHugeArtboardOnlyClampsToTheSmallestStop() {
    let huge = CGSize(width: 20000, height: 20000)
    for (name, size) in viewports {
        let layout = EditorDetailLayout(viewport: size, toolCount: 6)
        #expect(unclamped(layout, huge) < smallestZoom, "\(name)")
        #expect(layout.fitScale(artboard: huge) == smallestZoom, "\(name)")
    }
}

@Test func editorDetailDegenerateSizesNeverGiveABadZoom() {
    let sizes = [
        CGSize.zero, CGSize(width: -100, height: -50), CGSize(width: 1, height: 1),
        CGSize(width: CGFloat.infinity, height: 600), CGSize(width: CGFloat.infinity, height: .infinity),
        CGSize(width: CGFloat.nan, height: 600), CGSize(width: CGFloat.nan, height: .nan),
    ]
    let documents = artboards + [
        CGSize.zero, CGSize(width: -10, height: 40), CGSize(width: CGFloat.nan, height: 10),
        CGSize(width: CGFloat.infinity, height: 10),
    ]
    let windows = viewports.map { $0.1 }
    for size in sizes + windows {
        for count in [-1, 0, 6] {
            let layout = EditorDetailLayout(viewport: size, toolCount: count)
            #expect(layout.paletteFrame.minY >= 0)
            #expect(layout.paletteFrame.minX == SuiteSpacing.l)
            for document in documents {
                let scale = layout.fitScale(artboard: document)
                #expect(scale.isFinite && scale >= smallestZoom, "\(size) \(document)")
            }
        }
    }
    #expect(EditorDetailLayout(viewport: .zero, toolCount: 6).fitScale(artboard: CGSize(width: 800, height: 600)) == smallestZoom)
}

@Test func commandZeroAsksForTheHostsFitWhenOneIsSet() {
    let document = CGSize(width: 1600, height: 1000)
    let room = CGSize(width: 804, height: 637)
    let layout = EditorDetailLayout(viewport: room, toolCount: 6)
    let host: @Sendable (CGSize, CGSize) -> Double = { viewport, artboard in
        EditorDetailLayout(viewport: viewport, toolCount: 6).fitScale(artboard: artboard)
    }
    #expect(ZoomMath.fit(document: document, in: room, using: host) == layout.fitScale(artboard: document))
    // Without one, Command-0 is unchanged.
    #expect(ZoomMath.fit(document: document, in: room, using: nil) == ZoomMath.fit(document: document, in: room))
}
