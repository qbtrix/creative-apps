// Live/LiveViewerDragging.swift: the W0 stub of ViewerDragging. It hits
// nothing and a move throws `.notBuilt`; the drag-to-key feature (#207)
// replaces this file whole with the live type. Linux-safe.

public struct LiveViewerDragging: ViewerDragging {
    public init() {}
    public var unavailableHelp: String? { "Dragging a layer to key it arrives with #207." }
    public func hit(_ composition: HaloComposition, at frame: Int, point: HaloPoint) -> String? { nil }
    public func commitMove(
        _ layerID: String, by delta: HaloPoint, at frame: Int, in composition: inout HaloComposition
    ) throws {
        throw HaloEditError.notBuilt("Dragging")
    }
}
