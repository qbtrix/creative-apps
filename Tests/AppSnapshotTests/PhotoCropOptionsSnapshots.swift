// PhotoCropOptionsSnapshots.swift: the crop tool's options (photo-crop CP-4,
// PV-3) on an 800 x 600 image. Writes photo-crop-options-light/dark.png (the
// empty state: Crop picked, no crop, Free, the fields disabled under "Drag on
// the image, or pick a shape, to start a crop.") and
// photo-crop-ratio-light/dark.png (1:1 locked, a centered 600 x 600 pending
// crop, Y disabled since the crop spans the full height). `gridAligned` checks blueprint 7.4 rule
// 5: the four fields' frames (CropFieldBoundsKey) form a 2 x 2 grid, X over W and Y
// over H, equal widths within 1 pt. macOS only.
import AppKit
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoCropOptionsSnapshots {
    /// An 800 x 600 image (a gradient with a darker band) with the Crop tool picked.
    private func opened() throws -> PhotoWorkspace {
        let (w, h) = (800, 600)
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let band = y > 380 && y < 460
                bytes[i] = band ? 30 : UInt8(60 + x * 160 / w)
                bytes[i + 1] = band ? 60 : UInt8(100 + y * 120 / h)
                bytes[i + 2] = band ? 90 : 210
            }
        }
        var model = PhotoWorkspace()
        try model.open(rgba8: bytes, width: w, height: h, name: "beach.png")
        model.selectTool(.crop)
        return model
    }

    @Test func emptyState() throws {
        let model = try opened()
        #expect(model.tool == .crop && model.pendingCrop == nil && model.cropAspect == .free)
        #expect(!model.cropFieldsEnabled)
        #expect(model.cropCaption == "Drag on the image, or pick a shape, to start a crop.")
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1, tab: .adjust),
                name: "photo-crop-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func squareLocked() throws {
        var model = try opened()
        model.setCropAspect(.ratio(1, 1))
        #expect(model.cropFieldValue(.width) == 600 && model.cropFieldValue(.height) == 600)
        #expect(model.cropFieldValue(.x) == 100 && model.cropFieldValue(.y) == 0)
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1, tab: .adjust),
                name: "photo-crop-ratio-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// A portrait-swapped ratio still lights its preset chip.
    @Test func swappedRatioSelectsItsPreset() {
        #expect(CropOptions.preset(for: .ratio(2, 3)) == .ratio(3, 2))
        #expect(CropOptions.preset(for: .ratio(9, 16)) == .ratio(16, 9))
        #expect(CropOptions.preset(for: .ratio(1, 1)) == .ratio(1, 1))
        #expect(CropOptions.preset(for: .original) == .original)
    }

    /// Blueprint 7.4 rule 5, measured from the bounds each field reports
    /// through CropFieldBoundsKey in a panel-wide host. SwiftUI builds a
    /// hosting view's accessibility tree only when an assistive client asks,
    /// so a headless runner has no accessibility frames to read.
    @Test func gridAligned() throws {
        var model = try opened()
        model.setCropAspect(.ratio(1, 1))
        let frames = fieldFrames(
            in: CropOptions(model: model, perform: { _ in }).padding(SuiteSpacing.m),
            size: CGSize(width: SuiteSize.editorPanelWidth, height: 480))
        let x = try #require(frames["photo.crop.x"], "no photo.crop.x among \(frames.keys.sorted())")
        let y = try #require(frames["photo.crop.y"])
        let w = try #require(frames["photo.crop.width"])
        let h = try #require(frames["photo.crop.height"])
        #expect(x.width > 0 && x.height > 0, "photo.crop.x has no size: \(x)")
        for frame in [y, w, h] { #expect(abs(frame.width - x.width) <= 1, "field widths differ: \(frames)") }
        #expect(abs(x.minX - w.minX) <= 1, "X is not over W: \(x) \(w)")
        #expect(abs(y.minX - h.minX) <= 1, "Y is not over H: \(y) \(h)")
        #expect(abs(x.midY - y.midY) <= 1 && abs(w.midY - h.midY) <= 1, "a row is ragged: \(frames)")
        #expect(y.minX > x.maxX && h.minX > w.maxX, "the columns overlap: \(frames)")
        #expect(x.midY != w.midY, "the two rows share a line: \(frames)")
    }

    /// Each crop field's frame in `view`'s space, resolved from its
    /// CropFieldBoundsKey anchor once `view` is hosted in a window and laid
    /// out (the way `render` and ControlInventoryTests host a view).
    private func fieldFrames(in view: some View, size: CGSize) -> [String: CGRect] {
        let seen = MeasuredFields()
        let measured = view
            .frame(width: size.width, height: size.height, alignment: .top)
            .overlayPreferenceValue(CropFieldBoundsKey.self) { anchors in
                GeometryReader { proxy in
                    Color.clear.preference(key: ResolvedFieldFramesKey.self, value: anchors.mapValues { proxy[$0] })
                }
            }
            .onPreferenceChange(ResolvedFieldFramesKey.self) { frames in
                MainActor.assumeIsolated { seen.frames = frames }
            }
        let host = NSHostingView(rootView: measured)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        return seen.frames
    }
}

@MainActor private final class MeasuredFields {
    var frames: [String: CGRect] = [:]
}

/// The crop fields' frames once resolved in the measuring host's space.
private struct ResolvedFieldFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, next in next }
    }
}
