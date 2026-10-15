// CropOverlay.swift: a pending crop over the canvas: SuiteUI's CropShade
// (the outside dimmed, the frame and its thirds) and its element
// `photo.canvas.crop`, "Crop area". Nothing without a pending crop.
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
            }
        }
    }
}
