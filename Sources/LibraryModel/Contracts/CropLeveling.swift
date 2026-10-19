// Contracts/CropLeveling.swift: the crop's Auto slot (CR-2), its own
// protocol so `CropGeometry` stays as it is. `LibraryServices.leveler` holds
// one when Auto can run: `.fake` sets `FakeCrop`, `.live` leaves it nil until
// `LiveCrop` levels over core (CR-10); `levelHelp` then says why Auto is off.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// J6 Auto. Live: `LiveCrop` once core detects horizons. Fake: `FakeCrop`.
public protocol CropLeveling: Sendable {
    /// The clockwise turn, in degrees, that levels the horizon in `image`;
    /// nil when it finds none.
    func levelAngle(_ image: PixelBuffer) throws -> Double?
}

extension LibraryCatalog {
    /// The services' leveler; nil until one is connected.
    public var leveler: (any CropLeveling)? { services.leveler }
    /// Why Auto can't run: nil when `leveler` is set.
    public var levelHelp: String? {
        leveler == nil ? "Auto-straighten isn't connected yet (crop)." : nil
    }
}
