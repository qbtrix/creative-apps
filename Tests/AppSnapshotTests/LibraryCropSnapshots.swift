// LibraryCropSnapshots.swift: Library's loupe in crop mode (crop CR-6) on
// the shoot fixture's IMG_0001, a 6000 × 4000 photo, Light and Dark: the
// browser with the frame overlay beside the CROP section, on 1:1 at 0°
// (`library-crop`, the frame "4000 × 4000 at 1000, 0") and straightened to
// 5° (`library-crop-straightened`, a smaller square on the turned photo), and
// on 4:5 turned portrait through the catalog's crop.set-aspect
// (`library-loupe-crop-portrait`, orientation-crop OC-10: a tall frame and the
// aspect picker's portrait toggle).
// The crop controls come in through `\.libraryCrop`, filled from the catalog
// as LibraryWindow's `cropControls` fills them, with closures that do
// nothing. Also the overlay's handle hit test, which the loupe's drags use.
// macOS only.
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryCropSnapshots {
    /// The shoot by name, IMG_0001 open in the loupe with its sample picture, a 1:1 draft at `angle`.
    private func cropping(angle: Double) throws -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.setSort(.name)
        let order = catalog.sortedItems.map(\.id)
        try #require(order.count == 24)
        catalog.open(order[0])
        let pending = catalog.loupeRequest(longSide: 1024, quality: .full)
        let request = try #require(pending)
        let image = try #require(SampleImage.image(for: request.photo, longSide: 1024))
        catalog.showLoupeRender(RenderedPhoto(image: image, histogram: .empty, quality: .full), token: request.token)
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        if angle != 0 { catalog.setCropAngle(angle) }
        return catalog
    }

    /// What `cropControls` hands the views, with closures that change nothing.
    private func controls(_ catalog: LibraryCatalog) -> LibraryMenu.Crop {
        // Field by field: one initializer holding every closure is too much for the type checker.
        var crop = LibraryMenu.Crop()
        crop.draft = catalog.cropDraft
        crop.frame = catalog.cropFrame
        crop.canvas = catalog.cropCanvas
        crop.frameValue = catalog.cropFrameValue
        crop.artboard = catalog.loupeItem.map { catalog.croppedSize($0) }
        crop.resetHelp = catalog.resetCropHelp
        crop.levelHelp = catalog.levelHelp
        let none: LibraryMenu.Action = {}
        crop.setAspect = { (_: CropAspect) in }
        crop.pick = { (_: CropPick) in }
        crop.drag = { (_: CropHandle, _: Double, _: Double) in }
        crop.setAngle = { (_: Double) in }
        if catalog.levelHelp == nil { crop.level = none }
        crop.apply = none
        crop.cancel = none
        crop.reset = none
        return crop
    }

    private func shoot(_ catalog: LibraryCatalog, _ name: String) throws {
        let crop = controls(catalog)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HStack(spacing: 0) {
                    LibraryBrowser(model: catalog).frame(minWidth: 0, maxWidth: .infinity)
                    DevelopInspector(model: catalog, menu: LibraryMenu(), cropDraft: catalog.cropDraft)
                        .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(SuiteColor.panel)
                }
                .environment(\.libraryCrop, crop)
                .frame(width: 1440, height: 900),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func square() throws {
        let catalog = try cropping(angle: 0)
        #expect(catalog.cropFrameValue == "4000 × 4000 at 1000, 0")
        #expect(catalog.cropCanvas == PixelSize(width: 6000, height: 4000))
        try shoot(catalog, "library-crop")
    }

    @Test func straightened() throws {
        let catalog = try cropping(angle: 5)
        #expect(catalog.cropDraft?.angle == 5)
        let frame = try #require(catalog.cropFrame)
        #expect(frame.width < 4000 && frame.width == frame.height)
        try shoot(catalog, "library-crop-straightened")
    }

    @Test func portrait() throws {
        var catalog = try cropping(angle: 0)
        let params: JSONValue = .object(["aspect": .string("4:5"), "orientation": .string("portrait")])
        _ = try LibraryCatalog.catalog.run("crop.set-aspect", params: params, on: &catalog)
        let frame = try #require(catalog.cropFrame)
        #expect(catalog.cropDraft != nil, "set-aspect closed the draft")
        #expect(abs(Double(frame.width) / Double(frame.height) - 0.8) < 0.01, "4:5 portrait framed \(frame)")
        try shoot(catalog, "library-loupe-crop-portrait")
    }

    /// A press within half a hit target of a corner or edge midpoint grabs
    /// that handle; anywhere else grabs the whole frame.
    @Test func handleHits() {
        let frame = CGRect(x: 1000, y: 0, width: 4000, height: 4000)
        let radius = 50.0
        #expect(LibraryCropOverlay.handle(at: CGPoint(x: 1010, y: 10), frame: frame, radius: radius) == .topLeft)
        #expect(LibraryCropOverlay.handle(at: CGPoint(x: 3000, y: 0), frame: frame, radius: radius) == .top)
        #expect(LibraryCropOverlay.handle(at: CGPoint(x: 5040, y: 4040), frame: frame, radius: radius) == .bottomRight)
        #expect(LibraryCropOverlay.handle(at: CGPoint(x: 1000, y: 2030), frame: frame, radius: radius) == .left)
        #expect(LibraryCropOverlay.handle(at: CGPoint(x: 3000, y: 2000), frame: frame, radius: radius) == .inside)
        #expect(LibraryCropOverlay.handle(at: CGPoint(x: 1100, y: 100), frame: frame, radius: radius) == .inside)
        #expect(LibraryCropOverlay.handleID(.topLeft) == "library.crop.handle.topLeft")
        #expect(Set(CropHandle.allCases.map(LibraryCropOverlay.handleID)).count == CropHandle.allCases.count)
    }
}
