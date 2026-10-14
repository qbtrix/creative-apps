// Live/LiveCrop.swift: spine stub. The crop feature replaces this file
// with the live conformance and sets `unavailable` to nil; until then every
// call throws the reason, and controls that need it are disabled with it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct LiveCrop: CropGeometry {
    public static let unavailable: String? = "Crop isn't connected yet (crop)."
    static var notBuilt: LibraryError { .invalid(unavailable ?? "") }
    public init() {}

    public func initial(aspect: CropAspect, angle: Double, photo: PixelSize) throws -> CropSettings { throw Self.notBuilt }

    public func dragged(_ crop: CropSettings, handle: CropHandle, dx: Double, dy: Double,
                        photo: PixelSize) throws -> CropSettings { throw Self.notBuilt }

    public func straightened(_ crop: CropSettings, angle: Double, photo: PixelSize) throws -> CropSettings { throw Self.notBuilt }

    public func frame(_ crop: CropSettings, photo: PixelSize) throws -> PixelRect { throw Self.notBuilt }
}
