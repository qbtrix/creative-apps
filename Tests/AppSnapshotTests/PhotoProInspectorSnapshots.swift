// PhotoProInspectorSnapshots.swift: Photo's inspector in the Pro density
// layout for a new 1920 × 1080 image with Background selected and every
// adjustment section open: the InspectorHeader with the Model's detail
// lines, the Layer section, Tool Options, then the flush, hairline-separated adjustment sections
// with Gamma as a ScrubField. Light and Dark. Writes
// photo-inspector-layer-light.png and photo-inspector-layer-dark.png, then
// the same panel as tall as its whole content, so the inspector is drawn
// down to its last section (Blur, with its Radius) without scrolling:
// photo-inspector-layer-end-light.png and photo-inspector-layer-end-dark.png
// (2×, through SnapshotHost, framed to the content's fitting size). The
// padded panel fits the 1440 × 900 canvas, so neither end is cropped (#1714).
// An offscreen render never applied a default scroll anchor (#1733, #1811),
// so nothing here scrolls. macOS only.
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

    /// The panel at the inspector's width, as tall as the canvas less its padding.
    private static func panel(_ model: PhotoWorkspace) -> some View {
        PhotoPanel(model: model)
            .frame(
                width: SuiteSize.inspectorWidth.ideal, height: canvas.height - 2 * SuiteSpacing.xxl,
                alignment: .topLeading)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
    }

    /// The panel at its ideal height: PhotoAdjustTab's scroll view takes the
    /// height of all its content, so the whole tab is laid out and nothing clips.
    private static func fullPanel(_ model: PhotoWorkspace) -> some View {
        PhotoPanel(model: model)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
    }

    /// The padded full panel's fitting size: the frame the end snapshot draws at.
    private static func fullSize(_ model: PhotoWorkspace) -> CGSize {
        NSHostingView(rootView: fullPanel(model)).fittingSize
    }

    @Test func layerInspector() throws {
        let model = try Self.workspace()
        #expect(model.selectedLayer?.name == "Background")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                Self.panel(model), name: "photo-inspector-layer-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// #1714: the whole inspector, down to its last section, drawn unclipped.
    @Test func layerInspectorEnd() throws {
        let model = try Self.workspace()
        let size = Self.fullSize(model)
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for appearance in [SnapshotAppearance.light, .dark] {
            let image = try #require(SnapshotHost(appearance: appearance).render(Self.fullPanel(model), size: size))
            let png = try #require(image.representation(using: .png, properties: [:]))
            try png.write(to: folder.appending(path: "photo-inspector-layer-end-\(appearance.rawValue).png"))
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

    /// #1714: the inspector's content has a finite height, taller than the
    /// panel the canvas gives it, and framed to that height the whole inspector is
    /// drawn: the last section's checkbox ("Blur Enabled") lies inside the
    /// frame, the band above the panel's bottom edge holds drawn rows (Blur's
    /// Radius) rather than plain fill, and the padding below it is backdrop.
    @Test func adjustTabEndIsReachable() throws {
        let model = try Self.workspace()
        let size = Self.fullSize(model)
        let pad = SuiteSpacing.xxl
        let content = size.height - 2 * pad
        #expect(content.isFinite && content < 20_000, "content height is \(content)")
        #expect(content > Self.canvas.height - 2 * pad, "content (\(content) pt) fits the panel: nothing below to reach")

        let window = Self.host(Self.fullPanel(model), size: size)
        defer { window.close() }
        let blur = try #require(Self.frame(ofLabel: "Blur Enabled", in: window), "no Blur Enabled checkbox")
        let panelRect = CGRect(origin: .zero, size: size).insetBy(dx: pad, dy: pad)
        #expect(panelRect.contains(blur), "Blur's checkbox at \(blur) is outside the panel \(panelRect)")

        let image = try #require(SnapshotHost(appearance: .light).render(Self.fullPanel(model), size: size))
        let scale = SnapshotHost.scale
        let left = Int(pad * scale), right = Int((pad + SuiteSize.inspectorWidth.ideal) * scale)
        let panelBottom = Int((size.height - pad) * scale)
        var colors = Set<NSColor>()
        for y in stride(from: panelBottom - Int(48 * scale), to: panelBottom, by: 2) {
            for x in stride(from: left, to: right, by: 2) {
                if let color = image.colorAt(x: x, y: y) { colors.insert(color) }
            }
        }
        #expect(colors.count >= 3, "the panel's bottom band is plain fill (\(colors.count) colors): its end isn't drawn")
        let backdrop = try #require(image.colorAt(x: image.pixelsWide - 1, y: 0))
        let below = try #require(image.colorAt(x: (left + right) / 2, y: image.pixelsHigh - 1))
        #expect(below == backdrop, "the bottom row is \(below), not the backdrop \(backdrop): the panel overruns")
    }

    /// `view` at `size` in an offscreen window ordered in, with AppKit
    /// accessibility on, so its nodes report frames.
    private static func host(_ view: some View, size: CGSize) -> NSWindow {
        NSApplication.shared.accessibilitySetValue(
            true, forAttribute: NSAccessibility.Attribute(rawValue: "AXManualAccessibility"))
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return window
    }

    /// The window-space frame of the first accessibility node labelled `label`, breadth first.
    private static func frame(ofLabel label: String, in window: NSWindow) -> CGRect? {
        var queue: [AnyObject] = window.contentView.map { [$0] } ?? []
        while !queue.isEmpty {
            let node = queue.removeFirst()
            if (node.accessibilityLabel?() ?? nil) == label, let screen = node.accessibilityFrame?() {
                return window.convertFromScreen(screen)
            }
            queue += ((node.accessibilityChildren?() ?? nil) ?? []).map { $0 as AnyObject }
        }
        return nil
    }
}
