// PhotoAreaSelectSnapshots.swift: the area tools on an 800 x 600 image (area-selection AR-11). Writes
// photo-select-ellipse-feather-light/dark.png (an ellipse feathered by 12 px, then inverted: the ants run round the
// ellipse and the canvas's edge) and photo-select-wand-light/dark.png (a click on the dark band with Contiguous off
// picks every dark pixel). photo-select-options-<tool>-light/dark.png show the inspector's Tool Options section for
// the Ellipse, the Polygon Lasso and the Magic Wand. macOS only.
import CoreRaster
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoAreaSelectSnapshots {
    /// An 800 x 600 gradient with two dark bands, `tool` picked.
    private func opened(_ tool: PhotoTool) throws -> PhotoWorkspace {
        let (w, h) = (800, 600)
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let band = (y > 140 && y < 200) || (y > 400 && y < 460)
                bytes[i] = band ? 30 : UInt8(60 + x * 160 / w)
                bytes[i + 1] = band ? 60 : UInt8(100 + y * 120 / h)
                bytes[i + 2] = band ? 90 : 210
            }
        }
        var model = PhotoWorkspace()
        try model.open(rgba8: bytes, width: w, height: h, name: "beach.png")
        model.selectTool(tool)
        return model
    }

    private func write(_ model: PhotoWorkspace, _ name: String) throws {
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func featheredInvertedEllipse() throws {
        var model = try opened(.ellipse)
        model.drag(from: Mask.Point(x: 200, y: 120), to: Mask.Point(x: 600, y: 480), modifiers: [])
        model.endDrag()
        _ = try PhotoWorkspace.catalog.run("select.feather", params: .object(["radius": .number(12)]), on: &model)
        _ = try PhotoWorkspace.catalog.run("select.invert", params: .object([:]), on: &model)
        #expect(model.areaOutline.count >= 2, "the ants run round the ellipse and the canvas's edge")
        #expect(model.selection.map { $0.width == 800 && $0.height == 600 } == true)
        try write(model, "photo-select-ellipse-feather")
    }

    @Test func wandWithContiguousOff() throws {
        var model = try opened(.wand)
        model.setAreaOptions(PhotoAreaOptions(tolerance: 20, contiguous: false))
        model.drag(from: Mask.Point(x: 300, y: 170), to: Mask.Point(x: 300, y: 170), modifiers: [])
        model.endDrag()
        #expect(model.areaOptions.contiguous == false)
        #expect(model.areaOutline.count >= 2, "both bands are picked")
        try write(model, "photo-select-wand")
    }

    @Test(arguments: [PhotoTool.ellipse, .polygon, .wand])
    func areaOptions(_ tool: PhotoTool) throws {
        var model = try opened(tool)
        model.setAreaOptions(PhotoAreaOptions(feather: 12, tolerance: 20, contiguous: false))
        for scheme in [ColorScheme.light, .dark] {
            let view = ToolOptionsSection(model: model, perform: { _ in })
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                .padding(SuiteSpacing.xxl)
            try snapshot(view, name: "photo-select-options-\(tool.rawValue)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
