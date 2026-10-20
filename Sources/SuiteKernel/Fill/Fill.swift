// Fill.swift (gradient-fill GF-1): the suite's fill is FlareCore's, under
// kernel names, so Flare's stored fills, every exporter and every app Model
// share one gradient model (contract rule 20: no app declares its own).
// `GradientFillTarget` is what an app's workspace conforms to so the eight
// fill commands in `GradientCommands` run on it.
import FlareCore

/// A shape's paint: FlareCore's `Fill` (`.solid(color)`, `.linear(stops, start, end)`, `.radial(stops, center, radius)`).
public typealias Fill = FlareCore.Fill

/// One colour stop: FlareCore's `GradientStop` (`offset` in 0...1, `color`).
public typealias GradientStop = FlareCore.GradientStop

/// A fill's colour: FlareCore's `Color`, sRGB 0...1 with straight alpha (SwiftUI owns the name `Color`).
public typealias FillColor = FlareCore.Color

/// The three fills the editor's switch offers.
public enum FillType: String, Codable, CaseIterable, Sendable { case solid, linear, radial }

/// The primary selected layer's fill, its points in `box`'s space (Design and Halo store a unit box and map it).
public struct FillSelection: Hashable, Sendable {
    /// The fill and the box its points are in.
    public var fill: Fill; public var box: Rect
    public init(fill: Fill, box: Rect) { (self.fill, self.box) = (fill, box) }
}

/// A document the fill commands run on: it reads the selection's fill and sets it back as one undo step.
public protocol GradientFillTarget: Sendable {
    /// The primary selected layer's fill; nil when nothing fillable is selected.
    var fillSelection: FillSelection? { get }
    /// Why the fill commands can't run now, in the app's words; nil when they can.
    var fillHelp: String? { get }
    /// Sets every selected fillable layer, mapped from `box` to its own box; one undo step named `name`,
    /// steps under one `drag` token fold into one.
    mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws
}
