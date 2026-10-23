// AreaShape.swift (area-selection AR-1, AR-3 bodies): a selection that is an area, not only a rectangle: the
// shapes in order, each joined to the area before it, then invert, feather and expand. SuiteImaging masks it (AR-6).

/// One shape an area tool draws, in document space.
public enum AreaShape: Hashable, Sendable, Codable {
    /// A rectangle, and an ellipse inscribed in a rect.
    case rect(Rect), ellipse(Rect)
    /// A freehand outline, and clicked corners; `AreaRecipe.normalized` closes both and simplifies the lasso.
    case lasso([Point]), polygon([Point])
    /// The pixels like the seed's within `tolerance` (0...255 per channel), touching it unless not `contiguous`,
    /// sampled on the layer or, with `allLayers`, the composite.
    case wand(seed: Point, tolerance: Double, contiguous: Bool, allLayers: Bool)
}

/// How a new shape joins the area there is: replaces it, joins it (Shift), cuts it (Option) or keeps only what
/// both share (Shift and Option).
public enum AreaCombine: String, Hashable, Sendable, Codable, CaseIterable {
    /// The four modes.
    case replace, add, subtract, intersect
    /// The mode the held keys ask for: Shift adds, Option subtracts, both intersect; Command alone changes nothing.
    public init(_ modifiers: EditModifiers) {
        let shift = modifiers.contains(.shift), option = modifiers.contains(.option)
        self = shift ? (option ? .intersect : .add) : (option ? .subtract : .replace)
    }
}

/// The area as the ordered steps that make it.
public struct AreaRecipe: Hashable, Sendable, Codable {
    /// One step: a shape joined by its mode, or a change to the whole area so far.
    public enum Step: Hashable, Sendable, Codable {
        /// A shape joined to the area by a mode, and everything that was not selected.
        case shape(AreaShape, AreaCombine), invert
        /// The edge softened over a radius in pixels; the edge moved out by one (negative is Contract).
        case feather(Double), expand(Double)
    }
    /// The steps in the order they apply.
    public private(set) var steps: [Step] = []
    /// An empty recipe; `apply` adds its steps.
    public init() {}
    /// Nothing selected.
    public static let empty = AreaRecipe()
    /// True when the recipe selects nothing: it has no step.
    public var isEmpty: Bool { steps.isEmpty }
    /// Adds `step` after the others: a replace shape clears the earlier steps, and an invert right after an invert
    /// takes it back, so invert twice is the recipe before.
    public mutating func apply(_ step: Step) {
        switch step {
        case .shape(_, .replace): steps = [step]
        case .invert where steps.last == .invert: steps.removeLast()
        default: steps.append(step)
        }
    }
    /// The recipe with each lasso and polygon closed and each lasso's points under 1 px apart dropped; a normalized
    /// recipe normalizes to itself.
    public func normalized() -> AreaRecipe {
        var copy = self
        copy.steps = steps.map { step in
            switch step {
            case .shape(.lasso(let points), let mode): return .shape(.lasso(Self.closed(Self.simplified(Self.open(points)))), mode)
            case .shape(.polygon(let points), let mode): return .shape(.polygon(Self.closed(Self.open(points))), mode)
            default: return step
            }
        }
        return copy
    }

    /// `points` without a closing point that repeats the first.
    static func open(_ points: [Point]) -> [Point] {
        guard points.count > 1, let first = points.first, points.last == first else { return points }
        return Array(points.dropLast())
    }
    /// `points` closed by repeating the first at the end; empty stays empty.
    static func closed(_ points: [Point]) -> [Point] {
        guard let first = points.first, points.count > 1 else { return points }
        return points + [first]
    }
    /// `points` with each point under 1 px from the last one kept dropped; the first is always kept.
    static func simplified(_ points: [Point]) -> [Point] {
        var kept: [Point] = []
        for point in points {
            if let last = kept.last {
                let dx = point.x - last.x, dy = point.y - last.y
                if dx * dx + dy * dy < 1 { continue }
            }
            kept.append(point)
        }
        return kept
    }
}
