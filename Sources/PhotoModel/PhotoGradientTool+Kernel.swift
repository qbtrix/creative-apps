// PhotoGradientTool+Kernel.swift (gradient-fill PG-1 stubs; PG-3 and PG-4
// bodies): the Gradient tool's adapter onto the kernel. The tool's options
// hold the kernel's `Fill`, edited through `GradientRules` by the editor's
// `GradientIntent`s, and its pixels are creative-core's raster gradient
// (rule 20: no Photo gradient type). A drag's release calls `drawGradient`
// (PhotoStroke.swift's `endDrag`), which writes core's dithered
// `PixelBuffer.gradient` into the selected layer through the positional
// `editSelection`, so it stays inside the selection. `runGradientOption` is
// a stub until PG-4. Linux-safe.
import CoreColor
import CoreRaster
import FlareCore
import SuiteKernel

/// Why a gradient can't be drawn: its `Fill` is solid or has under two stops.
enum GradientDrawError: Error, Equatable {
    case notAGradient
}

extension PhotoWorkspace {
    /// Draws the tool's gradient into the selected layer, inside the selection
    /// when there is one, from `a` (offset 0) to `b` (offset 1) in canvas
    /// pixels, as one "Gradient" undo step. A click (`a == b`) draws nothing.
    /// The stops mix in OKLab (core's default), so the ramp is perceptually even.
    public mutating func drawGradient(from a: Mask.Point, to b: Mask.Point) throws {
        try drawGradient(toolOptions.gradient, from: a, to: b)
    }

    /// `fill` drawn as `drawGradient(from:to:)` draws the tool's; what
    /// `image.gradient` runs. Its stops are sRGB, decoded to linear light for
    /// core, and a linear fill runs along `a`→`b`, a radial one out from `a`
    /// to the circle through `b`. Throws `GradientDrawError` for a fill that
    /// isn't a gradient, and core's `RasterError` for bad stops.
    mutating func drawGradient(_ fill: Fill, from a: Mask.Point, to b: Mask.Point) throws {
        guard a != b, canvas != nil, let id = paintLayerID(), let at = index(of: id),
            let bounds = bounds(of: layers[at])
        else { return }
        let shape: RasterGradientShape
        switch fill {
        case .linear: shape = .linear
        case .radial: shape = .radial
        case .solid: throw GradientDrawError.notAGradient
        }
        guard fill.stops.count >= 2 else { throw GradientDrawError.notAGradient }
        let selected: PixelRect? = selection
        let region = selected ?? bounds
        guard let area = region.intersection(bounds) else { return }
        let stops = fill.stops.map { stop in
            RasterGradientStop(offset: Float(stop.offset), color: Self.linearLight(stop.color))
        }
        let ramp = try PixelBuffer.gradient(
            width: area.width, height: area.height, shape: shape,
            from: Mask.Point(x: a.x - Double(area.x), y: a.y - Double(area.y)),
            to: Mask.Point(x: b.x - Double(area.x), y: b.y - Double(area.y)),
            stops: stops, dither: true)
        editSelection(named: "Gradient", in: region, masked: selected != nil) { x, y, old in
            // Inside `area` by construction: the edit visits only region ∩ the layer.
            guard let g = try? ramp.pixel(x: x - area.x, y: y - area.y) else { return old }
            let k = 1 - g.a
            return RGBA(r: g.r + old.r * k, g: g.g + old.g * k, b: g.b + old.b * k, a: g.a + old.a * k)
        }
    }

    /// `color`'s sRGB components in linear light, straight alpha, as core's
    /// gradient stops take them.
    static func linearLight(_ color: Color) -> RGBA {
        let srgb = Color3(color.r, color.g, color.b)
        // A non-finite stop is left as is; core refuses it with its own error.
        let linear = (try? srgb.converted(from: .sRGB, to: .linearSRGB)) ?? srgb
        return RGBA(r: Float(linear.c0), g: Float(linear.c1), b: Float(linear.c2), a: Float(color.a))
    }

    /// One editor gesture on the tool's gradient (`toolOptions.gradient`),
    /// through `GradientRules`; not undoable, as every tool option.
    public mutating func runGradientOption(_ intent: GradientIntent) { setToolOption(.gradient(intent)) }
}
