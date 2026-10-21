// Orientation.swift (orientation-crop OC-1 stubs, OC-3 bodies): the eight ways an image can face,
// numbered as EXIF numbers them, and what an app gives the image.rotate-* and image.flip commands.
// Every sequence of turns and flips is one value, so it renders as one resample or one exact pixel op.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The eight ways an image can face, as EXIF numbers them: up (1) through the mirrored turns.
public enum Orientation: Int, Hashable, Sendable, Codable, CaseIterable {
    case up = 1, upMirrored, down, downMirrored, leftMirrored, right, rightMirrored, left

    /// This value turned a quarter, clockwise or counter-clockwise.
    public func rotated(clockwise: Bool) -> Orientation { self }

    /// This value mirrored left to right (horizontal) or top to bottom (vertical).
    public func flipped(_ d: FlipDirection) -> Orientation { self }

    /// This value followed by `next`: the one value that faces the image as both in turn.
    public func then(_ next: Orientation) -> Orientation { self }

    /// The size of a `w` x `h` image once it faces this way.
    public func size(_ w: Int, _ h: Int) -> (width: Int, height: Int) { (w, h) }

    /// The map of the unit square (y down) onto itself that faces it this way, for previews.
    public var matrix: Matrix { .identity }
}

/// What an app gives the image commands: why the image can't turn, how it faces, and the one
/// edit that records a named undo step.
public protocol OrientationTarget: Sendable {
    /// Why the image can't turn or flip, in the app's words; nil when it can.
    var orientationHelp: String? { get }
    /// How the image faces now.
    var orientation: Orientation { get }
    /// Faces the image `o` as one undo step named `name`.
    mutating func setOrientation(_ o: Orientation, name: String) throws
}
