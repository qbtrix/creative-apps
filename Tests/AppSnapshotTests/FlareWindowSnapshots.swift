// FlareWindowSnapshots.swift: Flare's whole window on SuiteWindow, hosted as
// the app hosts it: a titled, full-size-content NSWindow at its launch size
// (SuiteSize.windowLaunch) whose NSHostingView bridges the toolbar and title
// (`sceneBridgingOptions`), so NavigationSplitView's sidebar, inspector and
// toolbar draw. Only that window is captured (its frame view, toolbar
// included), one pixel per point, in Light, Dark and both with Increase
// Contrast: with no document (the empty state with New Animation, the
// toolbar's Undo, Redo, Save, Auto-key, Animate… and Export… disabled) and
// with the `bounce` fixture open (SCENES and LAYERS, the stage over the
// timeline, the inspector on Properties). `bounce` checks the shots: each is
// the window's size, the sidebar shows its rows (Ball's ink) and Dark's
// sidebar is darker than Light's (#1856). Then the inspector alone on its
// Library tab ("Not built yet"). Writes flare-window-empty-<appearance>.png,
// flare-window-bounce-<appearance>.png (light, dark, light-ic, dark-ic) and
// flare-inspector-library.png. macOS only.
import AppKit
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareWindowSnapshots {
    @Test func empty() throws {
        for appearance in SnapshotAppearance.allCases {
            let image = try Self.window(FlareWorkspace(launch: FlareLaunch(arguments: [])), appearance: appearance)
            try Self.write(image, name: "flare-window-empty-\(appearance.rawValue)")
        }
    }

    @Test func bounce() throws {
        var sidebarLuminance: [SnapshotAppearance: Double] = [:]
        for appearance in SnapshotAppearance.allCases {
            let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
            #expect(model.document != nil, "the bounce fixture opened no document")
            let image = try Self.window(model, appearance: appearance)
            let size = SuiteSize.windowLaunch
            #expect(image.pixelsWide == Int(size.width) && image.pixelsHigh == Int(size.height),
                    "flare-window-bounce-\(appearance.rawValue) is \(image.pixelsWide)x\(image.pixelsHigh)")
            let sidebar = Self.sidebarStats(image)
            // The rows' text (SCENES, LAYERS, Ball) is ink against the pane; a blank pane has none.
            #expect(sidebar.ink >= 40, "the \(appearance.rawValue) sidebar draws no rows (\(sidebar.ink) ink pixels)")
            sidebarLuminance[appearance] = sidebar.mean
            try Self.write(image, name: "flare-window-bounce-\(appearance.rawValue)")
        }
        if let light = sidebarLuminance[.light], let dark = sidebarLuminance[.dark] {
            #expect(dark < light, "the dark sidebar (\(dark)) is not darker than the light one (\(light))")
        }
        if let light = sidebarLuminance[.lightContrast], let dark = sidebarLuminance[.darkContrast] {
            #expect(dark < light, "the dark-ic sidebar (\(dark)) is not darker than the light-ic one (\(light))")
        }
    }

    @Test func library() throws {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        try snapshot(
            FlareInspector(model: model, tab: .library, perform: { _ in }, easing: EmptyView())
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, height: SuiteSize.windowLaunch.height, alignment: .top),
            name: "flare-inspector-library", scheme: .light)
    }

    /// FlareWindow on `model` in a real titled window at the launch size, in `appearance`, captured
    /// with its toolbar at one pixel per point.
    static func window(_ model: FlareWorkspace, appearance: SnapshotAppearance) throws -> NSBitmapImageRep {
        try SuiteHex.$increasedContrast.withValue(appearance.contrast == .increased) {
            try capture(model, appearance: appearance)
        }
    }

    private static func capture(_ model: FlareWorkspace, appearance: SnapshotAppearance) throws -> NSBitmapImageRep {
        let name = "flare-window-\(appearance.rawValue)"
        guard let named = NSAppearance(named: appearance.appearanceName) else { throw SnapshotError.render(name) }
        let size = SuiteSize.windowLaunch
        let host = NSHostingView(rootView: FlareWindow(model: model)
            .environment(\.suiteSnapshotRendering, true)
            .environment(\._colorSchemeContrast, appearance.contrast))
        host.sceneBridgingOptions = .all
        host.appearance = named
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = named
        window.contentView = host
        // Off every screen, never shown, but ordered in so AppKit lays out and draws the chrome.
        let frame = CGRect(origin: CGPoint(x: -20_000, y: -20_000), size: size)
        window.setFrame(frame, display: false)
        window.orderFrontRegardless()
        defer { window.close() }
        // Two layout passes around run-loop turns, so the split view, lists and toolbar settle.
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        window.setFrame(frame, display: true)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        // The frame view holds the content and the titlebar's toolbar; the content view alone has no toolbar.
        guard let chrome = host.superview ?? window.contentView else { throw SnapshotError.render(name) }
        chrome.layoutSubtreeIfNeeded()
        let bounds = chrome.bounds
        guard bounds.width > 0, bounds.height > 0, let image = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(bounds.width.rounded()), pixelsHigh: Int(bounds.height.rounded()),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)
        else { throw SnapshotError.render(name) }
        image.size = bounds.size
        chrome.cacheDisplay(in: bounds, to: image)
        return image
    }

    /// The sidebar's rows area, below the toolbar and clear of the column edges: its mean luminance and
    /// how many pixels stand out from it (text and symbols).
    static func sidebarStats(_ image: NSBitmapImageRep) -> (mean: Double, ink: Int) {
        let xs = 12..<min(Int(SuiteSize.sidebarWidth.ideal) - 12, image.pixelsWide)
        let ys = 64..<min(320, image.pixelsHigh)
        var values: [Double] = []
        for y in ys.lazy.filter({ $0 % 2 == 0 }) {
            for x in xs {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                values.append(0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent)
            }
        }
        guard !values.isEmpty else { return (0, 0) }
        let mean = values.reduce(0, +) / Double(values.count)
        return (mean, values.filter { abs($0 - mean) > 0.25 }.count)
    }

    /// Writes `image` to `<package root>/.build/snapshots/<name>.png`.
    static func write(_ image: NSBitmapImageRep, name: String) throws {
        guard let png = image.representation(using: .png, properties: [:]) else { throw SnapshotError.encode(name) }
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appending(path: "\(name).png"))
    }
}
