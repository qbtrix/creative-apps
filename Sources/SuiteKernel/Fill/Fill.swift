// Fill.swift (gradient-fill GF-1): the suite's fill is FlareCore's, under
// kernel names, so Flare's stored fills, every exporter and every app Model
// share one gradient model (contract rule 20: no app declares its own).
// `GradientFillTarget` is what an app's workspace conforms to so the eight
// fill commands in `GradientCommands` run on it. "No fill" lives beside the
// fill, not in it (FlareCore's `Fill` has no empty case): `FillSelection.isEmpty`
// and `clearFill`, which a target opts into; `FillType.none` is opt-in in the editor.
import FlareCore

/// A shape's paint: FlareCore's `Fill` (`.solid(color)`, `.linear(stops, start, end)`, `.radial(stops, center, radius)`).
public typealias Fill = FlareCore.Fill

/// One colour stop: FlareCore's `GradientStop` (`offset` in 0...1, `color`).
public typealias GradientStop = FlareCore.GradientStop

/// A fill's colour: FlareCore's `Color`, sRGB 0...1 with straight alpha (SwiftUI owns the name `Color`).
public typealias FillColor = FlareCore.Color

/// A layer's fill type: the three paints, or `none` for a layer with no fill (opt-in: `paints` leaves it out).
public enum FillType: String, Codable, CaseIterable, Sendable {
    case solid, linear, radial, none
    /// The three paints, the editor's default switch; a target that can go without a fill adds `.none`.
    public static let paints: [FillType] = [.solid, .linear, .radial]
}

/// What a fill keeps across type switches, in its box's space: the last linear angle, and the last radial centre
/// and radius. An app stores it beside the fill and saves it, so linear → radial → linear gives the angle back.
public struct FillMemory: Codable, Hashable, Sendable {
    /// The last linear angle in degrees; the last radial centre and radius.
    public var angle: Double?, center: Point?, radius: Double?
    public init(angle: Double? = nil, center: Point? = nil, radius: Double? = nil) {
        (self.angle, self.center, self.radius) = (angle, center, radius)
    }
}

/// The primary selected layer's fill, its points in `box`'s space (Design and Halo store a unit box and map it).
/// `isEmpty` is a layer with no fill; `fill` is then the paint it gets back when a type is picked again. `memory` is
/// what the fill keeps across type switches (empty for a target that doesn't store it).
public struct FillSelection: Hashable, Sendable {
    /// The fill and the box its points are in.
    public var fill: Fill; public var box: Rect
    /// True when the layer has no fill.
    public var isEmpty: Bool
    /// The fill's angle, centre and radius from before its last type switch.
    public var memory: FillMemory
    public init(fill: Fill, box: Rect, isEmpty: Bool = false, memory: FillMemory = FillMemory()) {
        (self.fill, self.box, self.isEmpty, self.memory) = (fill, box, isEmpty, memory)
    }
}

/// A document the fill commands run on: it reads the selection's fill and sets it back as one undo step.
public protocol GradientFillTarget: Sendable {
    /// The primary selected layer's fill; nil when nothing fillable is selected.
    var fillSelection: FillSelection? { get }
    /// Why the fill commands can't run now, in the app's words; nil when they can.
    var fillHelp: String? { get }
    /// Sets every selected fillable layer, mapped from `box` to its own box (a layer with no fill gets this one);
    /// one undo step named `name`, steps under one `drag` token fold into one.
    mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws
    /// `setFill`, saving `memory` beside the fill in the same undo step (a type switch). The default drops the memory,
    /// for a target that doesn't store it; a switch there starts a line at 0°.
    mutating func setFill(_ fill: Fill, memory: FillMemory, in box: Rect, name: String, drag: String?) throws
    /// Leaves every selected fillable layer with no fill, as one undo step named `name`. The default refuses with
    /// `GradientRules.noFillHelp`, for a target whose layers always have a fill.
    mutating func clearFill(name: String) throws
}

extension GradientFillTarget {
    public mutating func setFill(_ fill: Fill, memory: FillMemory, in box: Rect, name: String, drag: String?) throws {
        try setFill(fill, in: box, name: name, drag: drag)
    }
    public mutating func clearFill(name: String) throws {
        throw CatalogError.failed(id: "fill.type", message: GradientRules.noFillHelp)
    }
}
