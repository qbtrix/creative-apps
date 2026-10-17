// Geometry.swift (EK-1): the kernel's geometry is FlareCore's. `Point`,
// `Rect` and `Matrix` are FlareCore's own types under kernel names, so a
// Model that already holds FlareCore values hands them to the kernel as they
// are (editor-kernel design decision 2: no second geometry). The enums below
// are the words every kernel module and every SuiteUI half shares: which
// handle a drag holds, how a click picks, which way an arrow moves, which
// modifier keys were down.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// A point in document space: FlareCore's `Point` (x, y as `Double`).
public typealias Point = FlareCore.Point

/// An axis-aligned rectangle in document space: FlareCore's `Rect`.
public typealias Rect = FlareCore.Rect

/// A 2D affine transform: FlareCore's `Matrix` (`m * n` applies `n` first).
public typealias Matrix = FlareCore.Matrix

/// The ten places a pointer can hold a selection box: the eight resize
/// handles clockwise from the top-left corner, the inside (a move) and the
/// rotate knob. `BoxMath` resizes by one of these; `HandleHit` finds the one
/// under a point; `SelectionHandles` draws them.
public enum EditorHandle: CaseIterable, Sendable {
    /// The top-left corner handle.
    case topLeft
    /// The middle of the top edge.
    case top
    /// The top-right corner handle.
    case topRight
    /// The middle of the right edge.
    case right
    /// The bottom-right corner handle.
    case bottomRight
    /// The middle of the bottom edge.
    case bottom
    /// The bottom-left corner handle.
    case bottomLeft
    /// The middle of the left edge.
    case left
    /// Inside the box, on no handle: a drag here moves the selection.
    case inside
    /// The rotate knob above the box.
    case rotate

    /// True for the four corner handles, which resize on both axes (and keep
    /// the aspect ratio with Shift); false for the edges, the inside and rotate.
    public var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft: true
        case .top, .right, .bottom, .left, .inside, .rotate: false
        }
    }
}

/// How a click changes the selection: the one pick rule every app shares.
public enum Pick: Sendable {
    /// A plain click: the clicked item becomes the whole selection.
    case replace
    /// A Command-click: the clicked item joins the selection, or leaves it
    /// when it was already picked.
    case toggle
    /// A Shift-click: the range from the anchor to the clicked item joins the
    /// selection when the items have an order, otherwise the item alone joins.
    case extend
}

/// A direction an arrow key moves in: a nudge, or a selection move in a grid.
public enum Direction: Sendable {
    /// Up (towards smaller y on screen).
    case up
    /// Down (towards larger y on screen).
    case down
    /// Left (towards smaller x).
    case left
    /// Right (towards larger x).
    case right
}

/// The modifier keys an edit reads, as a set: Shift keeps the aspect ratio
/// or makes a nudge large, Option resizes around the centre, Command toggles
/// a pick. Platform-neutral so a Model and a test can build it without AppKit.
public struct EditModifiers: OptionSet, Sendable {
    /// The set's bits: shift is 1, option 2, command 4.
    public let rawValue: UInt8

    /// Builds the set from its raw bits.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// The Shift key.
    public static let shift = EditModifiers(rawValue: 1 << 0)
    /// The Option key.
    public static let option = EditModifiers(rawValue: 1 << 1)
    /// The Command key.
    public static let command = EditModifiers(rawValue: 1 << 2)
}
