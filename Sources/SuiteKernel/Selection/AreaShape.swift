// AreaShape.swift (area-selection AR-1 stubs, AR-3 bodies): a selection that is an area, not only a rectangle: the
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
    /// Adds `step` after the others; a replace shape clears the earlier steps. AR-1 stub: appends.
    public mutating func apply(_ step: Step) { steps.append(step) }
    /// The recipe with each lasso and polygon closed and each lasso's points under 1 px apart dropped. AR-1 stub: as is.
    public func normalized() -> AreaRecipe { self }
}
