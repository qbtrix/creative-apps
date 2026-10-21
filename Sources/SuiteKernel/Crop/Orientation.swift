// Orientation.swift (orientation-crop OC-a stubs, OC-m bodies): the eight ways an image can face,
// numbered as EXIF numbers them, and what an app gives the image.rotate-* and image.flip commands.
// Every sequence of turns and flips is one value, so it renders as one resample or one exact pixel op.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// The eight ways an image can face, as EXIF numbers them: up (1) through the mirrored turns.
public enum Orientation: Int, Hashable, Sendable, Codable, CaseIterable {
    case up = 1, upMirrored, down, downMirrored, leftMirrored, right, rightMirrored, left

    /// Quarter turns clockwise (0 to 3) after an optional left-right mirror: EXIF's eight as a pair.
    var turns: Int { switch self { case .up, .upMirrored: 0; case .right, .rightMirrored: 1; case .down, .downMirrored: 2; case .left, .leftMirrored: 3 } }
    var mirrored: Bool { [.upMirrored, .rightMirrored, .downMirrored, .leftMirrored].contains(self) }

    /// The value that mirrors `mirrored`, then turns `turns` quarters clockwise.
    init(turns: Int, mirrored: Bool) {
        let t = ((turns % 4) + 4) % 4
        self = Orientation.allCases.first { $0.turns == t && $0.mirrored == mirrored } ?? .up
    }

    /// This value turned a quarter, clockwise or counter-clockwise.
    public func rotated(clockwise: Bool) -> Orientation { then(clockwise ? .right : .left) }

    /// This value mirrored left to right (horizontal) or top to bottom (vertical).
    public func flipped(_ d: FlipDirection) -> Orientation { then(d == .horizontal ? .upMirrored : .downMirrored) }

    /// This value followed by `next`: the one value that faces the image as both in turn. A mirror
    /// reverses the turns before it, so `next`'s mirror counts this value's turns backwards.
    public func then(_ next: Orientation) -> Orientation {
        Orientation(turns: next.turns + (next.mirrored ? -turns : turns), mirrored: mirrored != next.mirrored)
    }

    /// The size of a `w` x `h` image once it faces this way: an odd number of turns swaps the sides.
    public func size(_ w: Int, _ h: Int) -> (width: Int, height: Int) { turns % 2 == 1 ? (h, w) : (w, h) }

    /// The map of the unit square (y down) onto itself that faces it this way, for previews: the
    /// mirror first, then the turns. Every entry is 0, 1 or -1, so products stay exact.
    public var matrix: Matrix {
        let quarter = Matrix(a: 0, b: 1, c: -1, d: 0, tx: 1, ty: 0), mirror = Matrix(a: -1, b: 0, c: 0, d: 1, tx: 1, ty: 0)
        return (0..<turns).reduce(mirrored ? mirror : .identity) { m, _ in quarter * m }
    }
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
