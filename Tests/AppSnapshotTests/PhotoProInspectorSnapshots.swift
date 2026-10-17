// PhotoProInspectorSnapshots.swift: Photo's inspector in the Pro density
// layout for a new 1920 × 1080 image with Background selected and every
// adjustment section open: the InspectorHeader with the Model's detail
// lines, the Layer section, Tool Options, then the flush, hairline-separated adjustment sections
// with Gamma as a ScrubField. Light and Dark. Writes
// photo-inspector-layer-light.png and photo-inspector-layer-dark.png, then
// the same panel scrolled to its end, so the last section (Blur, with its
// Radius) shows: photo-inspector-layer-end-light.png and
// photo-inspector-layer-end-dark.png. The padded panel fits the 1440 × 900
// canvas, so neither end is cropped (#1714). macOS only.
import AppKit
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoProInspectorSnapshots {
    /// The canvas `snapshot` and `render` draw at.
    private static let canvas = CGSize(width: 1440, height: 900)

    /// A new 1920 × 1080 image, Background selected.
    private static func workspace() throws -> PhotoWorkspace {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 1920, height: 1080)
        return model
    }

    /// The panel at the inspector's width, as tall as the canvas less its
    /// padding, its scroll view started at `anchor` (nil: the top).
    private static func panel(_ model: PhotoWorkspace, anchor: UnitPoint? = nil) -> some View {
        PhotoPanel(model: model, scrollAnchor: anchor)
            .frame(
                width: SuiteSize.inspectorWidth.ideal, height: canvas.height - 2 * SuiteSpacing.xxl,
                alignment: .topLeading)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
    }

    /// The panel with PhotoAdjustTab's own scroll view started at the bottom
    /// of its content. An anchor set on an ancestor doesn't reach that scroll
    /// view: the render matched the unscrolled one.
    private static func panelAtEnd(_ model: PhotoWorkspace) -> some View {
        panel(model, anchor: .bottom)
    }

    @Test func layerInspector() throws {
        let model = try Self.workspace()
        #expect(model.selectedLayer?.name == "Background")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                Self.panel(model), name: "photo-inspector-layer-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// #1714: the Adjust tab scrolled to its end shows the last section.
    @Test func layerInspectorEnd() throws {
        let model = try Self.workspace()
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                Self.panelAtEnd(model),
                name: "photo-inspector-layer-end-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// #1714: the padded panel fits the canvas, so the top and bottom pixel
    /// rows through the panel's column are the window backdrop, not panel
    /// fill. It stood 964 pt tall and lost 32 pt off each end.
    @Test func panelFitsCanvas() throws {
        let model = try Self.workspace()
        let fitting = NSHostingView(rootView: Self.panel(model)).fittingSize
        #expect(
            fitting.width <= Self.canvas.width && fitting.height <= Self.canvas.height + 0.5, "panel is \(fitting)")
        let x = Int(SuiteSpacing.xxl + SuiteSize.inspectorWidth.ideal / 2)
        for scheme in [ColorScheme.light, .dark] {
            let image = try #require(render(Self.panel(model), scheme: scheme))
            let backdrop = try #require(image.colorAt(x: Int(Self.canvas.width) - 1, y: 0))
            for y in [0, Int(Self.canvas.height) - 1] {
                let pixel = try #require(image.colorAt(x: x, y: y))
                #expect(pixel == backdrop, "row \(y) at x \(x) is \(pixel), not the backdrop \(backdrop)")
            }
        }
    }

    /// #1714: the Adjust tab's content is taller than the panel and its end is
    /// reachable: scrolled to the bottom, the panel's column draws differently
    /// from the top, and the panel still fits the canvas.
    @Test func adjustTabEndIsReachable() throws {
        let model = try Self.workspace()
        let fitting = NSHostingView(rootView: Self.panelAtEnd(model)).fittingSize
        #expect(fitting.height <= Self.canvas.height + 0.5, "scrolled panel is \(fitting)")
        let top = try #require(render(Self.panel(model), scheme: .light))
        let end = try #require(render(Self.panelAtEnd(model), scheme: .light))
        let left = Int(SuiteSpacing.xxl), right = Int(SuiteSpacing.xxl + SuiteSize.inspectorWidth.ideal)
        let bottom = Int(Self.canvas.height - SuiteSpacing.xxl) - 1
        let middle = Int(Self.canvas.height / 2)
        var changed = 0
        for y in stride(from: middle, to: bottom, by: 2) {
            for x in stride(from: left, to: right, by: 2) where top.colorAt(x: x, y: y) != end.colorAt(x: x, y: y) {
                changed += 1
            }
        }
        #expect(changed > 0, "the bottom half of the panel is the same scrolled to its end: nothing below to reach")
    }
}
