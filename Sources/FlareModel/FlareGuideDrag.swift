// FlareGuideDrag.swift: a guide drag on the stage (stage-edit SE-2, J14, QB-F3). The stage keeps one while the
// pointer is down and draws `shown(over:)`; the document changes once, on release, with the view intents `end`
// returns: a drag out of a ruler adds its guide ("Add Guide"), a drag of a guide moves it ("Move Guide", its step
// closed), and either released back over its ruler leaves no guide (a moved one is removed, "Remove Guide").
// Positions snap to whole scene points, as the guide's readout shows them.
import FlareCore

public struct FlareGuideDrag: Equatable, Sendable {
    /// The guide's axis: `.horizontal` for one pulled from the top ruler.
    public let axis: Guide.Axis
    /// The guide being moved; nil for a new one pulled out of a ruler.
    public let index: Int?
    /// Where the guide sat when the drag began, in scene points.
    public let start: Double
    /// Where the guide is now, in whole scene points.
    public private(set) var position: Double

    /// A new guide pulled out of the ruler along `axis`, at `position` scene points (0 when that isn't a number).
    public init(axis: Guide.Axis, at position: Double) {
        self.axis = axis
        index = nil
        start = position.isFinite ? position.rounded() : 0
        self.position = start
    }

    /// Guide `index` of `guides`, picked up where it sits; nil when there is no such guide.
    public init?(guide index: Int, of guides: [Guide]) {
        guard guides.indices.contains(index) else { return nil }
        axis = guides[index].axis
        self.index = index
        start = guides[index].position
        position = start
    }

    /// Moves the guide to `position`, to the whole scene point; one that isn't a number leaves it where it was.
    public mutating func move(to position: Double) {
        guard position.isFinite else { return }
        self.position = position.rounded()
    }

    /// The dragged guide's readout, as its mark will read once placed ("y 300").
    public var readout: String { "\(axis == .horizontal ? "y" : "x") \(FlareWorkspace.whole(position))" }

    /// The guides to draw during the drag: `guides` with the dragged one where the drag is, or the new one added.
    public func shown(over guides: [Guide]) -> [Guide] {
        var shown = guides
        let guide = Guide(axis: axis, position: position)
        guard let index else { return shown + [guide] }
        if shown.indices.contains(index) { shown[index] = guide }
        return shown
    }

    /// The view intents the release sends, one undo step or none: over its ruler a new guide is dropped and a moved
    /// one removed; elsewhere a new guide is added and a moved one moved (nothing when it is back where it began).
    public func end(overRuler: Bool) -> [FlareIntent] {
        switch (index, overRuler) {
        case (nil, true): return []
        case (nil, false): return [.view(.addGuide(horizontal: axis == .horizontal, at: position))]
        case (let index?, true): return [.view(.removeGuide(index: index))]
        case (let index?, false):
            guard position != start else { return [] }
            return [.view(.moveGuide(index: index, to: position, dragStart: start)), .view(.endGuideDrag)]
        }
    }
}
