// PhotoAreaTool.swift (area-selection AR-11): the Ellipse, Lasso, Polygon Lasso and Magic Wand tools, and a
// Marquee that joins or feathers. A release adds one shape to the area recipe as one undo step named for its
// command, joined by the held keys' mode or else the options', then feathered. A plain Marquee drag stays live
// (PV-5). The polygon closes on a click within 8 points of its first corner. Linux-safe.
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import CoreRaster
import SuiteKernel

/// The area tools' mode (with no key held), feather (0...250 px) and wand tolerance (0...255), Contiguous, All Layers.
public struct PhotoAreaOptions: Hashable, Sendable {
    public var mode: AreaCombine
    public var feather: Double
    public var tolerance: Double
    public var contiguous: Bool
    public var allLayers: Bool

    public init(mode: AreaCombine = .replace, feather: Double = 0, tolerance: Double = 32, contiguous: Bool = true,
                allLayers: Bool = false) {
        (self.mode, self.feather, self.tolerance, self.contiguous, self.allLayers) = (mode, feather, tolerance, contiguous, allLayers)
    }

    /// These options with feather and tolerance in their ranges; a value that isn't finite becomes 0.
    func clamped() -> PhotoAreaOptions {
        let clamp = { (value: Double, top: Double) in value.isFinite ? min(max(value, 0), top) : 0 }
        return PhotoAreaOptions(mode: mode, feather: clamp(feather, 250), tolerance: clamp(tolerance, 255),
                                contiguous: contiguous, allLayers: allLayers)
    }
}

/// The selection as it was when a Marquee drag began, put back when the drag joins instead.
struct PhotoAreaBefore: Sendable, Equatable {
    var selection: PixelRect?
    var mask: Mask?
    var area: PhotoArea
}

extension PhotoTool {
    /// The area command a release with this tool runs; nil for a tool that doesn't select.
    public var areaCommand: String? {
        self == .marquee ? "select.rect" : [.ellipse, .lasso, .polygon, .wand].contains(self) ? "select.\(rawValue)" : nil
    }
}

extension PhotoWorkspace {
    /// Sets the area tools' options, feather and tolerance clamped to their ranges.
    public mutating func setAreaOptions(_ options: PhotoAreaOptions) { areaOptions = options.clamped() }

    /// The outline an area tool shows before its release, in canvas pixels (the polygon's corners so far); or empty.
    public var areaDraft: [Point] {
        if tool == .polygon { return areaCorners.map(\.kernel) }
        guard let stroke else { return [] }
        switch stroke.tool {
        case .lasso: return stroke.points.map(\.kernel)
        case .ellipse: return areaShape(stroke).map { if case .ellipse(let r) = $0 { Self.ellipse(r) } else { [] } } ?? []
        case .marquee where marqueeJoins(stroke):
            guard case .rect(let r)? = areaShape(stroke) else { return [] }
            return [(r.minX, r.minY), (r.maxX, r.minY), (r.maxX, r.maxY), (r.minX, r.maxY), (r.minX, r.minY)].map { Point(x: $0.0, y: $0.1) }
        default: return []
        }
    }

    /// An area tool's drag to `end`: the Marquee's live rectangle unless it joins, the lasso's next point.
    mutating func areaDrag(_ current: inout PhotoStroke, to end: Mask.Point, modifiers: DragModifiers, zoom: Double, in canvas: CanvasSize) {
        current.end = end
        current.zoom = zoom
        if current.tool == .lasso {
            if current.points.isEmpty { current.points = [current.start] }
            if current.points.last != end { current.points.append(end) }
        }
        guard current.tool == .marquee else { return current.modifiers = modifiers }
        let before = current.areaBefore ?? PhotoAreaBefore(selection: selection, mask: selectionMask, area: area)
        current.areaBefore = before
        selectionDrag(&current, to: end, modifiers: modifiers, zoom: zoom, in: canvas)
        if marqueeJoins(current) { (selection, selectionMask, area) = (before.selection, before.mask, before.area) }
    }

    /// Ends an area tool's drag: adds its shape, or for the polygon, its corners until a click closes it.
    mutating func endAreaDrag(_ done: PhotoStroke) {
        if done.tool == .polygon { return polygonRelease(done) }
        if done.tool == .marquee, !marqueeJoins(done) { return }
        guard let shape = areaShape(done) else { return }
        addArea(shape, modifiers: done.modifiers, command: done.tool.areaCommand)
    }

    /// Whether a Marquee drag adds a step on release (it joins an area, or feathers) instead of being the selection as it drags.
    func marqueeJoins(_ stroke: PhotoStroke) -> Bool {
        let had = stroke.areaBefore.map { $0.selection != nil && !$0.area.recipe.isEmpty } ?? !areaRecipe.isEmpty
        return (had && areaMode(stroke.modifiers) != .replace) || areaOptions.feather > 0
    }

    /// The mode a shape joins by: the held keys' while Shift or Option is down, else the options'.
    func areaMode(_ keys: DragModifiers) -> AreaCombine {
        let held = (keys.contains(.shift) ? EditModifiers.shift : []).union(keys.contains(.option) ? .option : [])
        return held.isEmpty ? areaOptions.mode : AreaCombine(held)
    }

    /// The shape `stroke` draws: nil for a rectangle or ellipse under 1 px either way, or a lasso with no area.
    func areaShape(_ stroke: PhotoStroke) -> AreaShape? {
        let end = stroke.end ?? stroke.start
        switch stroke.tool {
        case .marquee, .ellipse:
            guard let r = Rect(enclosing: [stroke.start.kernel, end.kernel]), r.width >= 1, r.height >= 1 else { return nil }
            return stroke.tool == .marquee ? .rect(r) : .ellipse(r)
        case .lasso:
            return Self.area(stroke.points) >= 1 ? .lasso(stroke.points.map(\.kernel)) : nil
        case .wand:
            return .wand(seed: stroke.start.kernel, tolerance: areaOptions.tolerance, contiguous: areaOptions.contiguous,
                         allLayers: areaOptions.allLayers)
        default:
            return nil
        }
    }

    /// The polygon's press and release: each a new corner, unless the release lands within 8 points of the first
    /// corner of three or more, which closes the polygon and selects it.
    mutating func polygonRelease(_ done: PhotoStroke) {
        let end = done.end ?? done.start
        if areaCorners.count >= 3, let first = areaCorners.first, Self.distance(end, first) * done.zoom <= 8 {
            let corners = areaCorners
            areaCorners = []
            return addArea(.polygon(corners.map(\.kernel)), modifiers: done.modifiers, command: PhotoTool.polygon.areaCommand)
        }
        for point in [done.start, end] where areaCorners.last.map({ Self.distance($0, point) >= 1 }) ?? true {
            areaCorners.append(point)
        }
    }

    /// Joins `shape` to the recipe by the mode `modifiers` give, feathers it by the options, and sets the result as
    /// one undo step named for `command`.
    mutating func addArea(_ shape: AreaShape, modifiers: DragModifiers, command: String?) {
        var recipe = areaRecipe
        recipe.apply(.shape(shape, areaMode(modifiers)))
        if areaOptions.feather > 0 { recipe.apply(.feather(areaOptions.feather)) }
        do { try setArea(recipe.normalized(), command: command ?? "select.rect") } catch { statusMessage = "Couldn't make the selection." }
    }

    /// The area `points` enclose, by the shoelace formula, closed from the last point to the first.
    static func area(_ points: [Mask.Point]) -> Double {
        guard let last = points.last else { return 0 }
        var sum = 0.0, previous = last
        for point in points {
            sum += previous.x * point.y - point.x * previous.y
            previous = point
        }
        return abs(sum) / 2
    }

    static func distance(_ a: Mask.Point, _ b: Mask.Point) -> Double { ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot() }

    /// The ellipse inscribed in `r` as 48 points, closed.
    static func ellipse(_ r: Rect) -> [Point] {
        let (cx, cy, rx, ry) = ((r.minX + r.maxX) / 2, (r.minY + r.maxY) / 2, r.width / 2, r.height / 2)
        return (0...48).map { i in
            let t = Double(i % 48) * 2 * Double.pi / 48
            return Point(x: cx + rx * cos(t), y: cy + ry * sin(t))
        }
    }
}
