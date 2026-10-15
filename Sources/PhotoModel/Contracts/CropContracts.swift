// Contracts/CropContracts.swift: a crop rectangle from typed numbers and an
// aspect lock (PV-3, #544). Every result lies inside the canvas, at least
// 1 x 1, and keeps the aspect when one is set. Linux-safe.
import CoreRaster

/// The crop's shape lock.
public enum CropAspect: Hashable, Sendable {
    case free
    /// The canvas's own width : height.
    case original
    /// Width : height, both at least 1. `portrait` swaps them.
    case ratio(Int, Int)

    public static let presets: [CropAspect] = [.free, .original, .ratio(1, 1), .ratio(3, 2), .ratio(4, 3), .ratio(16, 9)]

    public var title: String {
        switch self {
        case .free: "Free"
        case .original: "Original"
        case .ratio(let w, let h): "\(w):\(h)"
        }
    }
}

/// One of the four numbers the crop options show.
public enum CropField: Hashable, Sendable, CaseIterable {
    case x, y, width, height
}

/// PV-3: crop geometry.
public protocol CropSizing: PhotoUseCase {
    /// `crop` with `field` set to `value`, clamped to the canvas. With an
    /// aspect, setting width moves height (and the reverse) about the
    /// top-left corner; X and Y move without resizing.
    func setting(_ field: CropField, to value: Int, in crop: PixelRect, aspect: CropAspect,
                 canvas: CanvasSize) -> PixelRect
    /// The rect a crop drag from `anchor` to `point` makes, keeping `aspect`
    /// (the larger of the two sides wins) and clamped to the canvas.
    func dragged(from anchor: Mask.Point, to point: Mask.Point, aspect: CropAspect, canvas: CanvasSize) -> PixelRect
    /// `crop` reshaped to `aspect` about its center, as large as fits inside
    /// both it and the canvas; the largest centered rect when `crop` is nil.
    func applying(_ aspect: CropAspect, to crop: PixelRect?, canvas: CanvasSize) -> PixelRect
    /// `aspect` with its sides swapped (3:2 becomes 2:3); free and original stay.
    func swapped(_ aspect: CropAspect, canvas: CanvasSize) -> CropAspect
}
