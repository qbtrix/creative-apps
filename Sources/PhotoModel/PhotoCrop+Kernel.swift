// PhotoCrop+Kernel.swift (orientation-crop OC-12): Photo's crop frame on the kernel's CropRules. A
// pending crop in whole pixels becomes a kernel Rect in canvas pixels and back, rounded to the
// nearest pixel, at least 1 x 1 and inside the canvas. Swap turns the frame about its centre,
// filling the same share of the canvas. Linux-safe.
import SuiteKernel

extension PhotoWorkspace {
    /// `crop` turned to the other orientation by the kernel's `CropRules.swapped`.
    func kernelSwapped(_ crop: PixelRect, canvas: CanvasSize) -> PixelRect {
        let bounds = Rect(minX: 0, minY: 0, maxX: Double(canvas.width), maxY: Double(canvas.height))
        let frame = Rect(minX: Double(crop.x), minY: Double(crop.y), maxX: Double(crop.maxX), maxY: Double(crop.maxY))
        return Self.pixels(of: CropRules.swapped(frame, in: bounds), canvas: canvas)
    }

    /// `r` rounded to whole pixels, at least 1 x 1, moved inside the canvas.
    static func pixels(of r: Rect, canvas: CanvasSize) -> PixelRect {
        let cw = max(canvas.width, 1), ch = max(canvas.height, 1)
        let w = min(max(Int(r.width.rounded()), 1), cw), h = min(max(Int(r.height.rounded()), 1), ch)
        let x = min(max(Int(r.minX.rounded()), 0), cw - w), y = min(max(Int(r.minY.rounded()), 0), ch - h)
        return PixelRect(x: x, y: y, width: w, height: h)
    }
}
