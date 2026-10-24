// Contracts/OutputContracts.swift: export at a size (PV-8) and the
// eyedropper's sample size (PV-9; the sample itself is SuiteKernel's
// `SampleRules.mean`, read in PhotoSample+Kernel.swift). Linux-safe.
import CoreRaster
import SuiteKernel

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

/// How many pixels the eyedropper averages: the kernel's, which every app's
/// eyedropper and `color.sample` share (eyedropper PE-1).
public typealias SampleSize = SuiteKernel.SampleSize
