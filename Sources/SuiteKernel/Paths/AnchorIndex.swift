// AnchorIndex.swift (pen-paths PN-1 stub answering nil and [], PN-6 body): anchors and handles on a grid of `cell` points.
public struct AnchorIndex: Sendable {
    public static let cell = 64.0
    public init(_ path: VectorPath, toDocument: Matrix) {}
    /// What is under `point` within `reach`: a selected anchor's handle, then an anchor, then a segment.
    public func hit(_ point: Point, reach: Double, selected: Selection<AnchorRef>) -> PathHit? { nil }
    /// The anchors inside `rect`, sorted.
    public func inside(_ rect: Rect) -> [AnchorRef] { [] }
    public var count: Int { 0 }
}
