// Contracts/OutputContracts.swift: export at a size (PV-8) and the
// eyedropper's sample (PV-9). Linux-safe.
import CoreRaster

/// How big Export writes the image.
public enum ExportSize: Hashable, Sendable {
    /// 1...400 percent of the canvas.
    case percent(Double)
    /// The longer side in pixels, 1...16384, the other side in proportion.
    case longestSide(Int)
}

/// The Export sheet's choices.
public struct ExportOptions: Hashable, Sendable {
    public var format: ImageFormat
    /// 0...1, for the formats that take one (JPEG, HEIC).
    public var quality: Double
    public var size: ExportSize
    public init(format: ImageFormat = .png, quality: Double = 0.9, size: ExportSize = .percent(100)) {
        self.format = format; self.quality = quality; self.size = size
    }
}

/// PV-8: the size Export writes.
public protocol ExportSizing: PhotoUseCase {
    /// The output size for `canvas` at `size`, each side rounded and at
    /// least 1. Throws `PhotoRefusal("Export is limited to 16384 pixels a
    /// side.")` past `PhotoWorkspace.maxSide`.
    func outputSize(for canvas: CanvasSize, _ size: ExportSize) throws -> CanvasSize
    /// `image` resampled to `size` (lanczos3 down, bilinear up); `image`
    /// itself when the size is unchanged.
    func resized(_ image: DecodedImage, to size: CanvasSize) throws -> DecodedImage
}

/// How many pixels the eyedropper averages.
public enum SampleSize: Int, Hashable, Sendable, CaseIterable {
    case point = 1, threeByThree = 3, fiveByFive = 5

    public var title: String {
        switch self {
        case .point: "Point"
        case .threeByThree: "3 × 3"
        case .fiveByFive: "5 × 5"
        }
    }
}

/// A sampled color, 8-bit sRGB like ToolOptions' color.
public struct SampledColor: Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red; self.green = green; self.blue = blue
    }
}

/// PV-9: the eyedropper.
public protocol ColorSampling: PhotoUseCase {
    /// The mean color of the `size` x `size` square centered on (x, y) in
    /// `picture` (the composited image around the point, with the point at
    /// `center` in it), over the pixels that are inside it and not fully
    /// transparent, straight alpha, encoded to sRGB. Nil when there are none.
    func sample(_ picture: PixelBuffer, center: (x: Int, y: Int), size: SampleSize) -> SampledColor?
}
