// PhotoLayerRowSnapshots.swift: Photo's Layers rows as the focused list draws
// them (#545): the selected row on the focused selection fill, the same row
// unfocused, and an unselected hidden row. The offscreen window never holds
// focus, so the focused row gets the fill the list's tint gives it
// (accentFill) and the increased background prominence the list sets. Writes
// photo-layer-row-focused-light.png and photo-layer-row-focused-dark.png, and
// measures the focused row's text and icons against its fill.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoLayerRowSnapshots {
    /// Two layers: "Background", hidden, and "Layer 1", selected, at Multiply 50%.
    private func layers() throws -> (selected: PhotoLayer, hidden: PhotoLayer) {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 64, height: 64)
        let background = try #require(model.selectedLayerID)
        model.toggleVisibility(background)
        model.addLayer()
        let top = try #require(model.selectedLayerID)
        model.setBlendMode(top, .multiply)
        model.setOpacity(top, percent: 50)
        let selected = try #require(model.layers.first { $0.id == top })
        let hidden = try #require(model.layers.first { $0.id == background })
        return (selected, hidden)
    }

    @Test func focusedSelectedRow() throws {
        let (selected, hidden) = try layers()
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LayerRows(selected: selected, hidden: hidden),
                name: "photo-layer-row-focused-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// The brightest pixel of the focused row's name, eye and blend label
    /// against its fill: at least 4.5:1 (WCAG AA for small text).
    @Test func focusedRowContrast() throws {
        let (selected, _) = try layers()
        for scheme in [ColorScheme.light, .dark] {
            let row = PhotoLayerRow(layer: selected, isSelected: true, perform: { _ in })
                .frame(width: 240)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SuiteColor.accentFill)
                .environment(\.backgroundProminence, .increased)
            let image = try #require(render(row, scheme: scheme))
            let ratio = try #require(Self.bestContrast(image))
            print("photo-layer-row-focused \(scheme == .dark ? "dark" : "light"): \(ratio):1")
            #expect(ratio >= 4.5, "focused layer row reads \(ratio):1")
        }
    }

    /// The highest WCAG contrast of any pixel against the top-left one (the fill).
    private static func bestContrast(_ image: NSBitmapImageRep) -> Double? {
        guard let data = image.bitmapData, image.samplesPerPixel >= 3 else { return nil }
        let (step, stride) = (image.bitsPerPixel / 8, image.bytesPerRow)
        func luminance(_ i: Int) -> Double {
            func channel(_ v: UInt8) -> Double {
                let c = Double(v) / 255
                return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(data[i]) + 0.7152 * channel(data[i + 1]) + 0.0722 * channel(data[i + 2])
        }
        let fill = luminance(0)
        var best = 1.0
        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                let l = luminance(y * stride + x * step)
                best = max(best, (max(l, fill) + 0.05) / (min(l, fill) + 0.05))
            }
        }
        return (best * 100).rounded() / 100
    }
}

/// The selected row focused, then unfocused, then a hidden row, in a panel.
private struct LayerRows: View {
    let selected: PhotoLayer
    let hidden: PhotoLayer

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            PhotoLayerRow(layer: selected, isSelected: true, perform: { _ in })
                .padding(SuiteSpacing.xs)
                .background(SuiteColor.accentFill, in: RoundedRectangle(cornerRadius: SuiteRadius.field))
                .environment(\.backgroundProminence, .increased)
            PhotoLayerRow(layer: selected, isSelected: true, perform: { _ in })
                .padding(SuiteSpacing.xs)
            PhotoLayerRow(layer: hidden, isSelected: false, perform: { _ in })
                .padding(SuiteSpacing.xs)
        }
        .padding(SuiteSpacing.m)
        .frame(width: 280, alignment: .leading)
        .background(SuiteColor.panel)
        .environment(\.colorScheme, .dark)
    }
}
