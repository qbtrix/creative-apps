// PhotoImageOps.swift: the Image menu's whole-image changes. Image Size
// resamples every layer by the same factors (CoreRaster's resized, bilinear)
// and scales its offset; Rotate turns every layer a quarter or half turn
// (CoreRaster's rotated) and moves its offset with it, so layers keep their
// places on the turned canvas. Each drops the selection and a pending crop and
// is one undo step keeping the whole stack, and tells every layer's extras
// (layerGeometryChanged, PV-5's masks) once. A size CoreRaster rejects throws
// and changes nothing. Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    /// The largest side Image Size accepts.
    public static let maxSide = 16384

    /// Resamples the image to `width` x `height` pixels. Throws
    /// `RasterError.invalid` for a side under 1 or over `maxSide`, or with no
    /// image open.
    public mutating func resizeImage(width: Int, height: Int) throws {
        guard let canvas else { throw RasterError.invalid("no image is open") }
        guard (1...Self.maxSide).contains(width), (1...Self.maxSide).contains(height) else {
            throw RasterError.invalid("size \(width)x\(height): each side must be 1 to \(Self.maxSide)")
        }
        guard width != canvas.width || height != canvas.height else { return }
        let sx = Double(width) / Double(canvas.width), sy = Double(height) / Double(canvas.height)
        var resized = stackState
        for (at, layer) in layers.enumerated() {
            guard let buffer = try pixels[layer.id]?.flattened() else { continue }
            let w = max(Int((Double(buffer.width) * sx).rounded()), 1)
            let h = max(Int((Double(buffer.height) * sy).rounded()), 1)
            resized.pixels[layer.id] = TiledPixels(try buffer.resized(width: w, height: h, filter: .bilinear))
            resized.layers[at].offsetX = Int((Double(layer.offsetX) * sx).rounded())
            resized.layers[at].offsetY = Int((Double(layer.offsetY) * sy).rounded())
        }
        resized.canvas = CanvasSize(width: width, height: height)
        resized.selection = nil
        record(.stack(stackState), named: "Image Size")
        restore(resized)
        for layer in layers { layerGeometryChanged(layer.id, .resized(scaleX: sx, scaleY: sy)) }
        touch(.all)
    }

    /// Turns the whole image clockwise by `turn`.
    public mutating func rotateImage(_ turn: QuarterTurn) {
        guard let canvas else { return }
        record(.stack(stackState), named: "Rotate")
        let (w, h) = (canvas.width, canvas.height)
        for (at, layer) in layers.enumerated() {
            // A layer's own size always flattens, so this never skips one.
            guard let buffer = try? pixels[layer.id]?.flattened() else { continue }
            let (x, y, lw, lh) = (layer.offsetX, layer.offsetY, buffer.width, buffer.height)
            let offset = switch turn {
            case .degrees90: (h - (y + lh), x)
            case .degrees180: (w - (x + lw), h - (y + lh))
            case .degrees270: (y, w - (x + lw))
            }
            pixels[layer.id] = TiledPixels(buffer.rotated(turn))
            layers[at].offsetX = offset.0
            layers[at].offsetY = offset.1
        }
        for layer in layers { layerGeometryChanged(layer.id, .rotated(turn)) }
        if turn != .degrees180 { self.canvas = CanvasSize(width: h, height: w) }
        selection = nil
        pendingCrop = nil
        touch(.all)
    }
}

extension CanvasSize {
    /// The height that keeps these proportions at `width`, at least 1.
    public func height(forWidth width: Int) -> Int {
        guard self.width > 0 else { return max(height, 1) }
        return max(Int((Double(width) * Double(height) / Double(self.width)).rounded()), 1)
    }

    /// The width that keeps these proportions at `height`, at least 1.
    public func width(forHeight height: Int) -> Int {
        guard self.height > 0 else { return max(width, 1) }
        return max(Int((Double(height) * Double(width) / Double(self.height)).rounded()), 1)
    }
}
