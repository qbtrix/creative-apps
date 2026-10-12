// AppSnapshotTests.swift: the eye-bridge. Renders each app's main content view
// (empty and with a new document open, Light and Dark) and a gallery of
// SuiteUI's components to PNGs in .build/snapshots/, so agents that cannot run
// a Mac can still see what they built. CI uploads that folder as the
// `snapshots` artifact on every run. macOS only.
//
// ImageRenderer draws SwiftUI only: AppKit-backed chrome (split view, toolbar,
// inspector, lists) does not render, so these are content views, not whole
// windows. It also drops glass views entirely, so the renderer sets
// `suiteSnapshotRendering` and SuiteUI draws glass as a flat bordered stand-in;
// judge real glass on a Mac.
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
        try snapshotStates("design", empty: DesignCanvas(model: DesignWorkspace()), open: DesignCanvas(model: open))
    }

    @Test func photo() throws {
        var open = PhotoWorkspace()
        try open.newCanvas(width: 1920, height: 1080)
        try snapshotStates("photo", empty: PhotoCanvas(model: PhotoWorkspace()), open: PhotoCanvas(model: open))
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
    let size = CGSize(width: 1440, height: 900)
    let renderer = ImageRenderer(content: view
        .frame(width: size.width, height: size.height)
        .background(SuiteColor.windowBackground)
        .environment(\.colorScheme, scheme)
        .environment(\.suiteSnapshotRendering, true))
    renderer.scale = 1
    renderer.proposedSize = ProposedViewSize(size)
    guard let image = renderer.cgImage else { throw SnapshotError.render(name) }
    #expect(image.width == 1440 && image.height == 900, "\(name) is \(image.width)x\(image.height)")
    guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw SnapshotError.encode(name)
    }
    let folder = try packageRoot().appending(path: ".build/snapshots")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try png.write(to: folder.appending(path: "\(name).png"))
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
