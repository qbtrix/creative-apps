// DesignSample+Kernel.swift (eyedropper DY-1 stubs, DY-5 bodies): Design's adapter onto SuiteKernel's
// SampleTarget (Sample/SampleCommands.swift), so the Eyedropper tool, `color.sample` and `color.pick` read a
// colour the same way. A vector document samples what it paints: the visible layers at the point composited back
// to front as the canvas paints them (DesignPage.painted: a hidden subtree skipped, opacity multiplied down), each
// its fill (its gradient's colour there through GradientRules) and then its stroke, so the topmost wins; never the
// selection and never pixels. A group paints nothing of its own; a text layer counts as its box in its colour.
// The N × N square is SampleRules.mean over that composite at whole-point offsets. An apply sets the selection's
// fill, or its stroke with Option, as one named step. Linux-safe.
import SuiteKernel

extension DesignWorkspace: SampleTarget {
    /// Why nothing can be sampled now; nil once a document is open.
    public var sampleHelp: String? {
        isOpen ? nil : "Open a design first."
    }

    /// The colour of the topmost visible painted layer at `point` (page points), through whatever lies over it
    /// that isn't opaque, averaged over a `size` square; nil on empty canvas or a point that isn't finite.
    public func sampledColor(at point: Point, size: SampleSize) -> FillColor? {
        guard isOpen, let page = selectedPage, point.x.isFinite, point.y.isFinite else { return nil }
        return SampleRules.mean(x: 0, y: 0, size: size) { dx, dy in
            Self.composite(page.nodes, at: Point(x: point.x + Double(dx), y: point.y + Double(dy)))
        }
    }

    /// Sets the selection's fill (or its stroke when `toStroke`) to the colour in a `size` square at `point`
    /// (`sampledColor(at:size:)`), one "Fill" or "Stroke" step. A locked layer in the selection is left as it is;
    /// nothing selected, a locked primary layer, a drag under way, empty canvas or a colour already there refuses
    /// and changes nothing.
    public mutating func applySample(at point: Point, toStroke: Bool, size: SampleSize = .point) throws {
        guard let node = selectedNode else { throw DesignRefusal.nothingSelected }
        if isLockedInTree(node.id) { throw DesignRefusal.locked(node.name) }
        if let why = fillHelp { throw CatalogError.failed(id: "color.pick", message: why) }
        guard gesture == nil, let read = sampledColor(at: point, size: size) else { throw DesignRefusal.unchanged }
        let color = DesignColor(kernel: read)
        let before = snapshot
        for id in selectedNodeIDs where !isLockedInTree(id) {
            _ = pages.update(id) { node in
                if toStroke {
                    var stroke = node.stroke ?? .default
                    stroke.color = color.kernelColor
                    node.stroke = stroke
                } else {
                    node.paint(.solid(color.kernelColor))
                }
            }
        }
        guard snapshot != before else { throw DesignRefusal.unchanged }
        record(toStroke ? "Stroke" : "Fill", before: before)
    }
}

extension DesignWorkspace {
    /// The pixel `nodes` paint at `point`: every visible layer's fill, then its stroke, laid over what is under
    /// it back to front (straight alpha), each at its opacity times its ancestors'; nil where nothing paints.
    static func composite(_ nodes: [DesignNode], at point: Point) -> SampleRGBA? {
        var (r, g, b, a) = (0.0, 0.0, 0.0, 0.0)
        func over(_ color: FillColor, _ opacity: Double) {
            let top = min(max(color.a, 0), 1) * opacity
            let out = top + a * (1 - top)
            guard out > 0 else { return }
            r = (color.r * top + r * a * (1 - top)) / out
            g = (color.g * top + g * a * (1 - top)) / out
            b = (color.b * top + b * a * (1 - top)) / out
            a = out
        }
        func walk(_ nodes: [DesignNode], opacity: Double) {
            for node in nodes where !node.isHidden {
                let faded = opacity * (node.opacity.isFinite ? min(max(node.opacity, 0), 1) : 1)
                for color in node.paints(at: point) { over(color, faded) }
                walk(node.children, opacity: faded)
            }
        }
        walk(nodes, opacity: 1)
        guard a > 0 else { return nil }
        func byte(_ channel: Double) -> UInt8 { UInt8(clamping: SampleRules.byte(channel)) }
        return SampleRGBA(r: byte(r), g: byte(g), b: byte(b), a: byte(a))
    }
}

extension DesignNode {
    /// What this layer alone paints at `point` (page points), bottom first: its fill where the point is inside its
    /// outline, then its stroke where the point is within half the stroke's width of that outline. A group paints
    /// nothing; a text layer its box in its colour, with no stroke.
    func paints(at point: Point) -> [FillColor] {
        guard kind != .group else { return [] }
        let local = TransformRules.local(point, in: transformBox)
        var colors: [FillColor] = []
        if covers(local, inset: 0) { colors.append(fillColor(at: local)) }
        if kind != .text, let stroke, stroke.width > 0, stroke.width.isFinite {
            let half = stroke.width / 2
            if covers(local, inset: -half), !covers(local, inset: half) { colors.append(stroke.color) }
        }
        return colors
    }

    /// The fill's colour at `local` (the unturned frame's points): a gradient's colour at the point's offset along
    /// it, through `GradientRules.color(of:at:)`; a solid's own colour.
    func fillColor(at local: Point) -> FillColor {
        let fill = fill(in: frame.kernelRect)
        let offset: Double
        switch fill {
        case .solid(let color): return color
        case .linear(_, let start, let end):
            let (vx, vy) = (end.x - start.x, end.y - start.y)
            let length = vx * vx + vy * vy
            offset = length > 0 ? ((local.x - start.x) * vx + (local.y - start.y) * vy) / length : 0
        case .radial(_, let center, let radius):
            let (dx, dy) = (local.x - center.x, local.y - center.y)
            offset = radius > 0 ? (dx * dx + dy * dy).squareRoot() / radius : 0
        }
        return GradientRules.color(of: fill, at: offset.isFinite ? offset : 0)
    }

    /// Whether `local` lies inside the outline moved in by `inset` points (out, when negative): the ellipse for an
    /// ellipse, the box with its drawn corner radius for the rest. The edge counts.
    func covers(_ local: Point, inset: Double) -> Bool {
        let box = frame.kernelRect
        let (minX, minY, maxX, maxY) = (box.minX + inset, box.minY + inset, box.maxX - inset, box.maxY - inset)
        guard minX <= maxX, minY <= maxY, local.x >= minX, local.x <= maxX, local.y >= minY, local.y <= maxY else { return false }
        let (rx, ry) = ((maxX - minX) / 2, (maxY - minY) / 2)
        let (dx, dy) = (local.x - (minX + rx), local.y - (minY + ry))
        if kind == .ellipse {
            guard rx > 0, ry > 0 else { return dx == 0 || dy == 0 }
            return (dx / rx) * (dx / rx) + (dy / ry) * (dy / ry) <= 1
        }
        let radius = min(max(drawnCornerRadius - inset, 0), rx, ry)
        let (cx, cy) = (abs(dx) - (rx - radius), abs(dy) - (ry - radius))
        guard radius > 0, cx > 0, cy > 0 else { return true }
        return cx * cx + cy * cy <= radius * radius
    }
}
