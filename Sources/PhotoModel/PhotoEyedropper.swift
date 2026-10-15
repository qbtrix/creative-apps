// PhotoEyedropper.swift: the eyedropper (PV-9 owns this file). Each drag event
// asks `services.sampling` for the color of the composited image around the
// pointer (a `sampleSize` square, clipped to the image) and makes it the
// brush color. Picking a color is not a document edit, so it is never an undo
// step. A refused sample (the live NotBuilt sampler, whose help `toolHelp`
// gives) or a point off the image changes nothing. Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    /// Samples the image at `point` (canvas pixels) into the brush color.
    mutating func sampleDrag(at point: Mask.Point) {
        guard let canvas, point.x.isFinite, point.y.isFinite, abs(point.x) < 1e7, abs(point.y) < 1e7 else { return }
        let x = Int(point.x.rounded(.down)), y = Int(point.y.rounded(.down))
        let side = sampleSize.rawValue, half = side / 2
        guard (0..<canvas.width).contains(x), (0..<canvas.height).contains(y),
            let area = PixelRect(x: x - half, y: y - half, width: side, height: side).intersection(canvas.rect),
            let picture = try? composited(area),
            let color = services.sampling.sample(picture, center: (x: x - area.x, y: y - area.y), size: sampleSize)
        else { return }
        setToolOption(.color(red: color.red, green: color.green, blue: color.blue))
    }
}
