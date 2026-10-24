// AreaMask.swift (area-selection AR-5 stub, AR-6 body): the kernel's area recipe as a CoreRaster mask. Each shape
// renders to its own mask and joins the area by its mode; invert, feather and expand apply where they sit in the
// list, so a feather before a subtract keeps the cut hard. The outline is the mask's contours at 0.5, for the
// marching ants. Linux-safe.
import CoreRaster
import SuiteKernel

/// An area recipe turned into coverage.
public enum AreaMask {
    /// The two pictures the magic wand can sample: the target layer, or the composite with All Layers.
    public struct Sources: Sendable {
        /// The target layer's pixels, canvas-sized.
        public var layer: PixelBuffer
        /// The flattened picture, canvas-sized.
        public var composite: PixelBuffer
        /// Both pictures, each the mask's size.
        public init(layer: PixelBuffer, composite: PixelBuffer) {
            (self.layer, self.composite) = (layer, composite)
        }
    }

    /// The largest feather, expand or contract radius, in pixels: the commands' own limit.
    public static let maxRadius = 250.0

    /// The coverage `recipe` selects on a `width` x `height` canvas. Throws for a size CoreRaster rejects, or a wand
    /// step without `sources` or with sources of another size. A wand seed off the canvas selects nothing.
    public static func mask(_ recipe: AreaRecipe, width: Int, height: Int, sources: Sources?) throws -> Mask {
        var area = try Mask(width: width, height: height)
        for step in recipe.normalized().steps {
            switch step {
            case .shape(let shape, let mode):
                let next = try render(shape, width: width, height: height, sources: sources)
                switch mode {
                case .replace: area = next
                case .add: try area.add(next)
                case .subtract: try area.subtract(next)
                case .intersect: try area.intersect(next)
                }
            case .invert: area.invert()
            case .feather(let radius):
                let r = radius.isFinite ? min(max(radius, 0), maxRadius, Double(2 * max(width, height))) : 0
                area = try area.feathered(radius: r)
            case .expand(let radius) where radius < 0:
                area.invert()
                area = try dilated(area, radius: -radius)
                area.invert()
            case .expand(let radius): area = try dilated(area, radius: radius)
            }
        }
        return area
    }

    /// The closed outlines where `mask`'s coverage crosses 0.5, in canvas pixels, for the ants.
    public static func outline(_ mask: Mask) throws -> [[Point]] {
        try mask.contours(level: 0.5).map { ring in ring.map { Point(x: $0.x, y: $0.y) } }
    }

    /// One shape's own coverage, canvas-sized.
    static func render(_ shape: AreaShape, width: Int, height: Int, sources: Sources?) throws -> Mask {
        switch shape {
        case .rect(let r):
            let (x0, y0) = (min(r.minX, r.maxX), min(r.minY, r.maxY))
            return try Mask.rectangle(width: width, height: height, x: x0, y: y0, w: abs(r.maxX - r.minX), h: abs(r.maxY - r.minY))
        case .ellipse(let r):
            return try Mask.ellipse(width: width, height: height, centerX: (r.minX + r.maxX) / 2, centerY: (r.minY + r.maxY) / 2,
                                    radiusX: abs(r.maxX - r.minX) / 2, radiusY: abs(r.maxY - r.minY) / 2)
        case .lasso(let points), .polygon(let points):
            return try Mask.polygon(width: width, height: height, points: points.map { Mask.Point(x: $0.x, y: $0.y) })
        case .wand(let seed, let tolerance, let contiguous, let allLayers):
            guard let sources else { throw RasterError.invalid("the magic wand needs the layer and the composite to sample") }
            let picture = allLayers ? sources.composite : sources.layer
            guard picture.width == width, picture.height == height else {
                throw RasterError.invalid("wand picture \(picture.width)x\(picture.height) is not the canvas's \(width)x\(height)")
            }
            guard seed.x.isFinite, seed.y.isFinite, seed.x >= 0, seed.y >= 0, seed.x < Double(width), seed.y < Double(height) else {
                return try Mask(width: width, height: height)
            }
            let t = Float((tolerance.isFinite ? min(max(tolerance, 0), 255) : 0) / 255)
            return try picture.floodMask(from: (x: Int(seed.x), y: Int(seed.y)), tolerance: .within(t), contiguous: contiguous)
        }
    }

    /// `mask` with each pixel the largest coverage within `radius` pixels of it (a disk): Expand. Off the canvas
    /// counts as 0. The disk is cut into rows: the row `dy` away reaches `reach[dy]` pixels either side, which only
    /// grows as `dy` shrinks, so one running row max widened step by step serves every row, from the disk's top in.
    static func dilated(_ mask: Mask, radius: Double) throws -> Mask {
        let r = Int(radius.isFinite ? min(max(radius, 0), maxRadius) : 0)
        let (w, h) = (mask.width, mask.height)
        guard r > 0 else { return mask }
        var values = [Float](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w { values[y * w + x] = try mask.coverage(x: x, y: y) } }
        let reach: [Int] = (0...r).map { (dy: Int) -> Int in halfWidth(dy, radius: r) }
        var row = values, grown = 0, out = [Float](repeating: 0, count: w * h)
        for dy in stride(from: r, through: 0, by: -1) {
            while grown < reach[dy] {
                let last = row
                for i in 0..<(w * h) {
                    let x = i % w
                    row[i] = max(last[i], x > 0 ? last[i - 1] : 0, x < w - 1 ? last[i + 1] : 0)
                }
                grown += 1
            }
            for y in 0..<h {
                for source in Set([y - dy, y + dy]) where (0..<h).contains(source) {
                    for x in 0..<w { out[y * w + x] = max(out[y * w + x], row[source * w + x]) }
                }
            }
        }
        var buffer = try PixelBuffer(width: w, height: h)
        for y in 0..<h { for x in 0..<w { try buffer.setPixel(x: x, y: y, RGBA(r: 0, g: 0, b: 0, a: out[y * w + x])) } }
        return try Mask(from: buffer, .alpha)
    }

    /// How far the disk of `radius` reaches either side on the row `dy` from its centre.
    static func halfWidth(_ dy: Int, radius r: Int) -> Int {
        var k = 0
        while k < r, (k + 1) * (k + 1) + dy * dy <= r * r { k += 1 }
        return k
    }
}
