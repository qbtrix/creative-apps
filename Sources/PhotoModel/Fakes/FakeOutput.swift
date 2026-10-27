// Fakes/FakeOutput.swift: the output fake (blueprint 5.2): export sizing
// (PV-8). The eyedropper has no fake: its mean is the kernel's, pure.
// Deterministic and stateless.
// Linux-safe.
import CoreRaster

/// Percent sizes only; a resize returns a gray image of the asked size.
public struct FakeExportSizing: ExportSizing {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func outputSize(for canvas: CanvasSize, _ size: ExportSize) throws -> CanvasSize {
        guard case .percent(let p) = size, p.isFinite, p > 0, p <= 400 else { return canvas }
        return CanvasSize(width: max(Int((Double(canvas.width) * p / 100).rounded()), 1),
                          height: max(Int((Double(canvas.height) * p / 100).rounded()), 1))
    }
    public func resized(_ image: DecodedImage, to size: CanvasSize) throws -> DecodedImage {
        DecodedImage(rgba8: [UInt8](repeating: 128, count: size.width * size.height * 4),
                     width: size.width, height: size.height)
    }
}
