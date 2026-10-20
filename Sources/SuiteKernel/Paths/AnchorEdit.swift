// AnchorEdit.swift (pen-paths PN-1 stubs returning the input, PN-5 bodies): point edits on a path in its own space; insert,
// remove (high index to low) and convert go through FlareCore's `inserting(at:)`, `removingAnchor` and `converting`.
import FlareCore
public enum AnchorEdit {
    public static func moved(_ path: VectorPath, _ anchors: Set<AnchorRef>, dx: Double, dy: Double) -> VectorPath { path }
    public static func movingHandle(_ path: VectorPath, _ ref: AnchorRef, _ end: HandleEnd, to: Point, breaking: Bool) -> VectorPath { path }
    public static func inserting(_ path: VectorPath, at location: FlareCore.PathLocation) throws -> (path: VectorPath, ref: AnchorRef) { (path, AnchorRef(contour: 0, index: 0)) }
    public static func removing(_ path: VectorPath, _ anchors: Set<AnchorRef>) throws -> VectorPath { path }
    public static func converting(_ path: VectorPath, _ anchors: Set<AnchorRef>, to kind: AnchorKind) throws -> VectorPath { path }
    /// `point` snapped to `lines` within `tolerance`, the `moving` anchors left out.
    public static func snapped(_ point: Point, moving: Set<AnchorRef>, in path: VectorPath, lines: SnapLines, tolerance: Double) -> Point { point }
}
