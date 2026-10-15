// Fakes/FakeViewerDragging.swift: the ViewerDragging views, snapshots and
// journeys run on (#207). It answers through LiveViewerDragging, so hits and
// moves come from HaloKeyRules and can't drift apart. Linux-safe; never used
// by `.live`.

public struct FakeViewerDragging: ViewerDragging {
    private let live = LiveViewerDragging()
    public init() {}
    public func hit(_ composition: HaloComposition, at frame: Int, point: HaloPoint) -> String? {
        live.hit(composition, at: frame, point: point)
    }
    public func commitMove(
        _ layerID: String, by delta: HaloPoint, at frame: Int, in composition: inout HaloComposition
    ) throws {
        try live.commitMove(layerID, by: delta, at: frame, in: &composition)
    }
}
