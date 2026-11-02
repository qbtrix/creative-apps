// PhotoImageOps.swift: the Image menu's whole-image changes. Image Size
// resamples every layer by the same factors (CoreRaster's resized, bilinear)
// and scales its offset; Rotate is the kernel's Orientation
// (PhotoOrientation+Kernel.swift turns every layer, mask and offset). Canvas Size (transform PT-6) moves every layer
// by the anchor's share of the change (SuiteKernel's anchoredOrigin, rounded
// down as CoreRaster's padded is) and pads or crops the background layer to
// the new canvas, its new border in the background colour (white). Each drops
// the selection and a pending crop and is one undo step keeping the whole
// stack, and tells every layer's extras (layerGeometryChanged, PV-5's masks)
// once. A size CoreRaster rejects throws and changes nothing. Linux-safe.
import CoreRaster
import SuiteKernel

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

    /// The colour Canvas Size pads the background with: Photo's new images are white.
    public static let canvasBackground = RGBA(r: 1, g: 1, b: 1, a: 1)

    /// Image > Canvas Size: grows or crops the canvas to `width` x `height`
    /// about `anchor` as one "Canvas Size" step. Every layer moves with the
    /// anchor; the background is padded with `canvasBackground` or cropped to
    /// the new canvas. The same size does nothing. Throws `RasterError.invalid`
    /// with no image open or for a side under 1 or over `maxSide`, and a
    /// `PhotoRefusal` while Free Transform is open.
    public mutating func resizeCanvas(width: Int, height: Int, anchor: BoxAnchor) throws {
        guard let canvas else { throw RasterError.invalid("no image is open") }
        guard (1...Self.maxSide).contains(width), (1...Self.maxSide).contains(height) else {
            throw RasterError.invalid("size \(width)x\(height): each side must be 1 to \(Self.maxSide)")
        }
        if let help = flipHelp { throw PhotoRefusal(help) }
        guard width != canvas.width || height != canvas.height else { return }
        let origin = TransformRules.anchoredOrigin(old: (Double(canvas.width), Double(canvas.height)),
                                                   new: (Double(width), Double(height)), anchor)
        let dx = Int(origin.x.rounded(.down)), dy = Int(origin.y.rounded(.down))
        var resized = stackState
        for at in resized.layers.indices {
            resized.layers[at].offsetX += dx
            resized.layers[at].offsetY += dy
        }
        if let at = resized.layers.indices.last, let padded = try paddedBackground(width, height, Self.canvasAnchor(anchor), dx, dy) {
            resized.pixels[resized.layers[at].id] = TiledPixels(padded)
            resized.layers[at].offsetX = 0
            resized.layers[at].offsetY = 0
        }
        resized.canvas = CanvasSize(width: width, height: height)
        resized.selection = nil
        record(.stack(stackState), named: "Canvas Size")
        restore(resized)
        let crop = PixelRect(x: -dx, y: -dy, width: width, height: height)
        for layer in layers { layerGeometryChanged(layer.id, .cropped(crop)) }
        touch(.all)
    }

    /// The bottom layer padded or cropped to `width` x `height` with its image
    /// at (`dx`, `dy`) and every new pixel `canvasBackground`; nil when the
    /// bottom layer is not a pixel layer filling the canvas from (0, 0).
    private func paddedBackground(_ width: Int, _ height: Int, _ anchor: CanvasAnchor, _ dx: Int, _ dy: Int)
        throws -> PixelBuffer? {
        guard let canvas, let layer = layers.last, layer.kind == .pixels, layer.offsetX == 0, layer.offsetY == 0,
              let tiled = pixels[layer.id], tiled.width == canvas.width, tiled.height == canvas.height else { return nil }
        var padded = try tiled.flattened().padded(width: width, height: height, anchor: anchor)
        // The image's rows and columns on the new canvas; the strips around them are new.
        let top = min(max(dy, 0), height), bottom = min(max(dy + canvas.height, top), height)
        let left = min(max(dx, 0), width), right = min(max(dx + canvas.width, left), width)
        let strips = [(0, 0, width, top), (0, bottom, width, height - bottom),
                      (0, top, left, bottom - top), (right, top, width - right, bottom - top)]
        for (x, y, w, h) in strips where w > 0 && h > 0 {
            try padded.composite(PixelBuffer(width: w, height: h, fill: Self.canvasBackground), x: x, y: y, mode: .normal, opacity: 1)
        }
        return padded
    }

    /// CoreRaster's name for the kernel's anchor.
    static func canvasAnchor(_ anchor: BoxAnchor) -> CanvasAnchor {
        switch anchor {
        case .topLeft: .topLeft
        case .top: .top
        case .topRight: .topRight
        case .left: .left
        case .center: .center
        case .right: .right
        case .bottomLeft: .bottomLeft
        case .bottom: .bottom
        case .bottomRight: .bottomRight
        }
    }

    /// Turns the whole image clockwise by `turn` through the kernel's
    /// Orientation (PhotoOrientation+Kernel.swift), as one "Rotate" step.
    /// No image, or Free Transform open: nothing.
    public mutating func rotateImage(_ turn: QuarterTurn) {
        let o: Orientation = turn == .degrees90 ? .right : turn == .degrees180 ? .down : .left
        try? setOrientation(o, name: "Rotate")
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
