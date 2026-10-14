// AppSnapshotTests.swift: the eye-bridge. Renders each app's main content view
// (empty and with a new document open, Light and Dark) and a gallery of
// SuiteUI's components to PNGs in .build/snapshots/, so agents that cannot run
// a Mac can still see what they built. CI uploads that folder as the
// `snapshots` artifact on every run. macOS only.
//
// Each view is hosted in an NSHostingView inside an offscreen borderless
// window with the Light or Dark appearance and drawn with cacheDisplay, so
// AppKit-backed controls (sliders, fields, pickers, color wells, lists, scroll
// views) render for real, not as ImageRenderer's placeholders. Glass still
// draws as SuiteUI's flat bordered stand-in (`suiteSnapshotRendering`), since
// an offscreen window has no backdrop for it; judge real glass on a Mac.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import FlareApp
@testable import HaloApp
@testable import LibraryApp
@testable import PhotoApp
import DesignModel
import FlareModel
import HaloModel
import LibraryModel
import PhotoModel

@MainActor
@Suite struct AppSnapshotTests {
    @Test func flare() throws {
        var open = FlareWorkspace()
        open.newDocument()
        open.selectTool(.pen)
        try snapshotStates("flare", empty: FlareCanvas(model: FlareWorkspace()), open: FlareCanvas(model: open))
    }

    @Test func design() throws {
        var open = DesignWorkspace()
        open.newFile()
        try snapshotStates("design", empty: DesignEditor(model: DesignWorkspace()), open: DesignEditor(model: open, zoom: 0.5))
    }

    @Test func photo() throws {
        var open = PhotoWorkspace()
        try open.newCanvas(width: 1920, height: 1080)
        try snapshotStates(
            "photo", empty: PhotoEditor(model: PhotoWorkspace()),
            open: PhotoEditor(model: open, tiles: try photoTiles(open), zoom: 0.5))
    }

    @Test func library() throws {
        // One state until import lands: an empty catalog.
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(LibraryBrowser(model: LibraryCatalog()), name: "library-empty-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func halo() throws {
        var open = HaloProject()
        open.newComposition()
        try snapshotStates("halo", empty: HaloViewer(model: HaloProject()), open: HaloViewer(model: open))
    }

    @Test func suiteGallery() throws {
        // An action is disabled exactly when it says why (the gallery shows one).
        #expect(ToolbarAction("Pen", systemImage: "pencil.tip").isEnabled)
        let ellipse = ToolbarAction("Ellipse", systemImage: "circle", unavailableHelp: "Not built yet.")
        #expect(!ellipse.isEnabled && ellipse.help == "Not built yet.")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(Gallery(), name: "suiteui-gallery-\(scheme.name)", scheme: scheme)
        }
    }

    private func snapshotStates(_ app: String, empty: some View, open: some View) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(empty, name: "\(app)-empty-\(scheme.name)", scheme: scheme)
            try snapshot(open, name: "\(app)-open-\(scheme.name)", scheme: scheme)
        }
    }
}

/// Every SuiteUI component, over a gradient so glass has something to refract.
private struct Gallery: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.orange, .pink, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: SuiteSpacing.xl) {
                Text("SuiteUI").font(SuiteFont.title)
                HStack(spacing: SuiteSpacing.xl) {
                    ToolbarGroup([
                        ToolbarAction("Select", systemImage: "cursorarrow", isSelected: true),
                        ToolbarAction("Pen", systemImage: "pencil.tip"),
                        ToolbarAction("Rectangle", systemImage: "rectangle"),
                        ToolbarAction("Ellipse", systemImage: "circle", unavailableHelp: "Not built yet."),
                    ])
                    GlassPanel { Text("00:00:01:12").font(SuiteFont.monospacedDigits) }
                }
                HStack(alignment: .top, spacing: SuiteSpacing.xl) {
                    SurfaceCard(title: "Surface card", detail: "Flat content-layer card").frame(width: 280)
                    VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                        SidebarRow(SidebarItem(id: "a", title: "All Photos", systemImage: "photo.on.rectangle.angled", count: 12))
                        SidebarRow(SidebarItem(id: "f", title: "Favorites", systemImage: "heart"))
                    }
                    .padding(SuiteSpacing.m)
                    .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
                }
                HStack(alignment: .bottom, spacing: SuiteSpacing.s) {
                    ForEach(SuiteSpacing.scale, id: \.self) { step in
                        Rectangle().fill(.primary.opacity(0.6)).frame(width: step, height: step)
                    }
                }
                CanvasSurface(artboard: CGSize(width: 550, height: 400)).frame(width: 520, height: 260)
                EmptyStateView(
                    "Empty state", systemImage: "tray", message: "Says what to do next.",
                    action: ToolbarAction("Do It", systemImage: "plus"))
                    .frame(width: 520, height: 220)
                    .background(SuiteColor.windowBackground, in: RoundedRectangle(cornerRadius: SuiteRadius.large))
            }
            .padding(SuiteSpacing.xxl)
        }
    }
}

private extension ColorScheme {
    var name: String { self == .dark ? "dark" : "light" }
}

enum SnapshotError: Error {
    case render(String)
    case encode(String)
    case noPackageRoot
}

/// Renders `view` at 1440x900 (scale 1) over the window background and writes
/// `<package root>/.build/snapshots/<name>.png`.
@MainActor
func snapshot(_ view: some View, name: String, scheme: ColorScheme) throws {
    guard let image = render(view, scheme: scheme) else { throw SnapshotError.render(name) }
    #expect(image.pixelsWide == 1440 && image.pixelsHigh == 900, "\(name) is \(image.pixelsWide)x\(image.pixelsHigh)")
    guard let png = image.representation(using: .png, properties: [:]) else { throw SnapshotError.encode(name) }
    let folder = try packageRoot().appending(path: ".build/snapshots")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try png.write(to: folder.appending(path: "\(name).png"))
}

/// `view` drawn at 1440x900 points, one pixel per point, through AppKit.
@MainActor
func render(_ view: some View, scheme: ColorScheme) -> NSBitmapImageRep? {
    let size = CGSize(width: 1440, height: 900)
    let host = NSHostingView(rootView: view
        .frame(width: size.width, height: size.height)
        .background(SuiteColor.windowBackground)
        .environment(\.colorScheme, scheme)
        .environment(\.suiteSnapshotRendering, true))
    host.frame = CGRect(origin: .zero, size: size)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    window.contentView = host
    // Two layout passes around a short run loop turn, so lists and scroll views settle.
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    host.layoutSubtreeIfNeeded()
    guard let image = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { return nil }
    image.size = size
    host.cacheDisplay(in: host.bounds, to: image)
    return image
}

/// The directory holding Package.swift, found by walking up from this file.
func packageRoot(from file: String = #filePath) throws -> URL {
    var dir = URL(fileURLWithPath: file).deletingLastPathComponent()
    while dir.path != "/" {
        if FileManager.default.fileExists(atPath: dir.appending(path: "Package.swift").path) { return dir }
        dir.deleteLastPathComponent()
    }
    throw SnapshotError.noPackageRoot
}
