// Contracts/PhotoContractTypes.swift: what every Photo v2 use-case contract
// shares. A contract is a pure service over value types: it takes pixels,
// layers and geometry and returns new ones. PhotoWorkspace owns state and
// history; it calls a contract inside one recorded step, so a contract never
// records undo itself and a throw leaves the workspace unchanged.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// Every contract says whether it can run yet. Its text is the tooltip of
/// every control that needs it ("Not built yet (PV-5)."); nil once it works.
public protocol PhotoUseCase: Sendable {
    var unavailableHelp: String? { get }
}

/// A use case refused for a reason the person can fix, in the words the
/// window shows ("Nothing to paste.", "Merge Down needs a pixel layer below.").
public struct PhotoRefusal: Error, Equatable, Sendable {
    public var message: String
    public init(_ message: String) { self.message = message }
}

/// Modifier keys held during a canvas drag.
public struct DragModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// Keep the ratio, add to a selection, snap an angle to 15 degrees.
    public static let shift = DragModifiers(rawValue: 1)
    /// From the center, subtract from a selection.
    public static let option = DragModifiers(rawValue: 2)
}

/// Pixels placed on the canvas: a buffer and where its top-left pixel sits.
public struct PlacedPixels: Sendable, Equatable {
    public var pixels: TiledPixels
    public var x: Int
    public var y: Int
    public init(pixels: TiledPixels, x: Int, y: Int) {
        self.pixels = pixels; self.x = x; self.y = y
    }
}

/// One layer with what it draws: pixels for a pixel layer (nil for an
/// adjustment layer) and its mask, a buffer the layer's size whose gray is
/// the coverage, alpha 1 (nil for none).
public struct LayerContent: Sendable, Equatable {
    public var layer: PhotoLayer
    public var pixels: TiledPixels?
    public var mask: TiledPixels?
    public init(layer: PhotoLayer, pixels: TiledPixels?, mask: TiledPixels? = nil) {
        self.layer = layer; self.pixels = pixels; self.mask = mask
    }
}
