// GalleryPreviewValueTests.swift (findings #4229, #4230): readouts the suiteui journeys read with `.value`, hosted in a
// window and read from its accessibility tree as AXValue, which is what XCUIElement.value returns. A plain
// accessibility element sends its value only as the value description, so the journey read "" (#262); these must
// reach AXValue. The gradient page's preview reads "linear, 2 stops, 0°" to start; with wide.png placed, the place
// canvas reads "wide.png, 1200 by 400 pixels" and the File row "wide.png · PNG · 1200 × 400 px". macOS only.
import AppKit
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct GalleryPreviewValueTests {
    @Test func theGradientPreviewReportsItsFill() {
        let id = "suite.gallery.gradient-editor.preview"
        let values = hostedValues(id, GalleryGradientEditorPage(), size: CGSize(width: 1000, height: 700))
        #expect(!values.isEmpty, "no \(id) in the page's accessibility tree")
        #expect(values.allSatisfy { $0 == "linear, 2 stops, 0°" }, "the preview reads \(values)")
    }

    @Test func thePlaceCanvasAndFileRowReportThePlacedImage() {
        let (asset, image) = GalleryPlaceImage.placed(GalleryPlaceImage.samples[0])
        let canvas = hostedValues(
            "suite.place.canvas", GalleryPlaceCanvas(drawn: [(asset, image)], selected: asset, selectedImage: image),
            size: CGSize(width: 600, height: 500))
        #expect(!canvas.isEmpty && canvas.allSatisfy { $0 == "wide.png, 1200 by 400 pixels" }, "the canvas reads \(canvas)")
        let file = hostedValues(
            "suite.place.file", VStack { PlacedImageRows(asset: asset, formats: [.png, .svg]) { _ in } }
                .frame(width: SuiteSize.editorPanelWidth),
            size: CGSize(width: 400, height: 200))
        #expect(!file.isEmpty && file.allSatisfy { $0 == "wide.png · PNG · 1200 × 400 px" }, "the File row reads \(file)")
    }
}

/// `view` in an on-screen window, the AXValue of every element called `id` in it once one shows ("" for no string).
@MainActor private func hostedValues(_ id: String, _ view: some View, size: CGSize) -> [String] {
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered,
                          defer: false)
    window.contentView = NSHostingView(rootView: view)
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    spinUntil { !axValues(id, in: window).isEmpty }
    return axValues(id, in: window)
}

/// The AXValue of every element called `id` under `element`: a value sent only as the value description reads "".
@MainActor private func axValues(_ id: String, in element: Any) -> [String] {
    let node = element as AnyObject
    var found = [String]()
    if (node.accessibilityIdentifier?() ?? nil) == id {
        found.append((node as? NSObject)?.value(forKey: "accessibilityValue") as? String ?? "")
    }
    for child in (node.accessibilityChildren?() ?? nil) ?? [] { found += axValues(id, in: child) }
    return found
}
