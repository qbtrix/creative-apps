// PhotoToolOptionsBarTests.swift: the active tool's options live in the options
// bar under the toolbar, not in the inspector. The Adjust tab shows no tool
// control (`photo.tool.*`, the crop's, transform's, area's, gradient's or
// sample's); the bar shows the paint color (`photo.tool.color`) for every
// tool, the Paint Bucket included, and only the active tool's own controls.
// Hosts each view in a window and reads its accessibility tree. Writes
// photo-tool-options-bar-light.png and -dark.png: the bar for each kind of
// tool, one under another, at a content column's width. macOS only.
import AppKit
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoToolOptionsBarTests {
    /// Identifier prefixes only a tool's options carry.
    static let toolPrefixes = ["photo.tool.", "photo.crop.", "photo.transform.", "suite.area.", "suite.transform.",
                               "suite.gradient.", "suite.sample."]

    private func opened(_ tool: PhotoTool) throws -> PhotoWorkspace {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 640, height: 480)
        model.selectTool(tool)
        return model
    }

    /// The accessibility identifiers `view` shows in a window `size` big.
    private func identifiers(_ view: some View, size: CGSize = CGSize(width: 1200, height: 1600)) -> Set<String> {
        let app = NSApplication.shared
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        defer { window.orderOut(nil) }
        window.contentView = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        func walk(_ element: Any) -> [String] {
            let node = element as AnyObject
            let id = (node.accessibilityIdentifier?() ?? nil).map { [$0] } ?? []
            return id + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap(walk)
        }
        return Set(walk(window))
    }

    private func barIdentifiers(_ tool: PhotoTool) throws -> Set<String> {
        identifiers(PhotoToolOptionsBar(model: try opened(tool), perform: { _ in }), size: CGSize(width: 1200, height: 60))
    }

    @Test(arguments: [PhotoTool.brush, .bucket, .crop, .select, .gradient, .marquee, .wand, .eyedropper])
    func theAdjustTabShowsNoToolOptions(_ tool: PhotoTool) throws {
        let ids = identifiers(PhotoAdjustTab(model: try opened(tool), perform: { _ in }, showsLayerSettings: true))
        let stray = ids.filter { id in Self.toolPrefixes.contains { id.hasPrefix($0) } }
        #expect(stray.isEmpty, "the Adjust tab shows \(tool)'s options: \(stray.sorted())")
        #expect(!ids.contains("suite.inspector.section.tool-options"))
    }

    @Test func theBucketShowsItsColor() throws {
        let ids = try barIdentifiers(.bucket)
        for id in ["photo.tool.color", "photo.tool.tolerance", "photo.tool.contiguous", "photo.tool.all-layers"] {
            #expect(ids.contains(id), "the Paint Bucket's options show no \(id)")
        }
        #expect(!ids.contains("photo.tool.size"), "the Paint Bucket shows the brush's Size")
    }

    @Test func theBrushShowsOnlyItsOwnOptions() throws {
        let ids = try barIdentifiers(.brush)
        for id in ["photo.tool.color", "photo.tool.size", "photo.tool.hardness", "photo.tool.opacity", "photo.tool.preset"] {
            #expect(ids.contains(id), "the Brush's options show no \(id)")
        }
        for id in ["photo.tool.tolerance", "photo.tool.contiguous", "photo.crop.apply", "suite.area.feather"] {
            #expect(!ids.contains(id), "the Brush's options show another tool's \(id)")
        }
    }

    @Test func everyToolShowsThePaintColor() throws {
        for tool in [PhotoTool.eraser, .crop, .pen, .text, .marquee] {
            #expect(try barIdentifiers(tool).contains("photo.tool.color"), "\(tool) hides the paint color")
        }
    }

    @Test func theBarShowsTheBrushColorWhileTheEraserIsActive() throws {
        var model = try opened(.brush)
        model.setToolOption(.color(red: 220, green: 30, blue: 30))
        model.selectTool(.eraser)
        #expect(PhotoToolOptionsBar.paint(model) == HexColor(220, 30, 30))
    }

    /// Every kind of tool's bar at the content column of a 1440 pt window (sidebar and inspector beside it).
    @Test func barPerTool() throws {
        let tools: [PhotoTool] = [.brush, .clone, .bucket, .spotHeal, .marquee, .wand, .crop, .select, .gradient,
                                  .eyedropper, .text, .pen]
        let models = try tools.map { try opened($0) }
        for scheme in [ColorScheme.light, .dark] {
            let view = VStack(spacing: SuiteSpacing.s) {
                ForEach(models.indices, id: \.self) { PhotoToolOptionsBar(model: models[$0], perform: { _ in }) }
            }
            .frame(width: 860)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            try snapshot(view, name: "photo-tool-options-bar-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
