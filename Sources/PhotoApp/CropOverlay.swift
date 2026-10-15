// CropOverlay.swift: a pending crop over the canvas: SuiteUI's CropShade
// (the outside dimmed, the frame and its thirds) and its element
// `photo.canvas.crop`, "Crop area". While a ratio is locked, the lock's name
// ("1:1", "2:3", "Original") sits in a pill centred on the crop's top edge,
// just inside it, placed at the canvas zoom like the shade: the element
// `photo.canvas.crop.aspect`. No pill under Free. The pill is SuiteUI's
// GlassPanel (a floating readout) until SuiteUI has a canvas pill (#1209).
// Nothing without a pending crop. Values in, nothing out.
import PhotoModel
import SuiteUI
import SwiftUI

struct CropOverlay: View {
    let model: PhotoWorkspace
    let zoom: Double

    /// The pending crop's element; nil without one.
    var mark: PhotoCanvasMark? { model.pendingCrop.map { PhotoCanvasMark.crop($0.cgRect) } }

    var body: some View {
        if let crop = model.pendingCrop, let canvas = model.canvas, let mark = mark {
            ZStack(alignment: .topLeading) {
                CropShade(rect: crop.cgRect, documentSize: CGSize(width: canvas.width, height: canvas.height), zoom: zoom)
                PhotoCanvasMarkElement(mark: mark, zoom: zoom)
                if let badge = model.cropAspectBadge {
                    aspectPill(badge, on: crop.cgRect)
                }
            }
        }
    }

    /// `badge` in a pill centred on the top edge of `rect` (document pixels) at the zoom.
    private func aspectPill(_ badge: String, on rect: CGRect) -> some View {
        let box = rect.applying(CGAffineTransform(scaleX: zoom, y: zoom)).standardized
        return GlassPanel {
            Text(verbatim: badge)
                .font(SuiteFont.pill)
                .foregroundStyle(SuiteColor.textPrimary)
                .lineLimit(1)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: badge))
        .accessibilityIdentifier("photo.canvas.crop.aspect")
        .frame(width: box.width)
        .padding(.leading, box.minX)
        .padding(.top, box.minY + SuiteSpacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
