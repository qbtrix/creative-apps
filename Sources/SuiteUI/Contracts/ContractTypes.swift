// ContractTypes.swift: the value types every SuiteUI contract shares (points,
// extents, rects, key modifiers, grid arrows) and EditRun, the one-gesture-
// one-end rule. Foundation only, Swift 6, Sendable; verbatim from blueprint
// section 5.1 (docs/blueprints/suiteui/contracts/Contracts.swift).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A point in points (view space) or document pixels; the call says which.
public struct PlanePoint: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// A width and height. Not called "Size": `SuiteSize` is the size token enum.
public struct PlaneExtent: Hashable, Sendable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
}

public struct PlaneRect: Hashable, Sendable {
    public var origin: PlanePoint
    public var extent: PlaneExtent
    public init(x: Double, y: Double, width: Double, height: Double) {
        origin = PlanePoint(x: x, y: y); extent = PlaneExtent(width: width, height: height)
    }
    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + extent.width }
    public var maxY: Double { origin.y + extent.height }
    public var mid: PlanePoint { PlanePoint(x: origin.x + extent.width / 2, y: origin.y + extent.height / 2) }
    public func contains(_ p: PlanePoint) -> Bool { p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY }
}

public struct KeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let shift = KeyModifiers(rawValue: 1)    // coarse ×10, constrain, extend
    public static let option = KeyModifiers(rawValue: 2)   // fine ×0.1
    public static let command = KeyModifiers(rawValue: 4)  // toggle in a selection
}

public enum GridArrow: Sendable, CaseIterable { case left, right, up, down }

/// One gesture, one end. Every component that reports `onEnd` keeps one of
/// these: a drag, a typed commit, a key press or a nudge opens a run with its
/// first change and closes it once, so the host makes it one undo step.
public struct EditRun: Equatable, Sendable {
    public private(set) var isOpen = false
    public private(set) var ends = 0
    public init() {}
    /// Returns true when this change opened the run.
    public mutating func change() -> Bool {
        defer { isOpen = true }
        return !isOpen
    }
    /// Returns true exactly once per opened run; an end with no change is ignored.
    public mutating func end() -> Bool {
        guard isOpen else { return false }
        isOpen = false; ends += 1
        return true
    }
}
