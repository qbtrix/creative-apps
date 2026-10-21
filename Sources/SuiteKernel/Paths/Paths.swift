// Paths.swift (pen-paths PN-1): the suite's path is FlareCore's under kernel names (SuiteUI has its own mark-only
// `PathAnchor`), so stored paths, exporters and app Models share one model. Workspaces conform to `PathEditTarget`.
import FlareCore
/// FlareCore's `Path` (contours), `PathAnchor` (point, handleIn?, handleOut?, kind), `PathContour` (anchors, closed)
/// and `AnchorKind` (corner, smooth, symmetric).
public typealias VectorPath = FlareCore.Path
public typealias VectorAnchor = FlareCore.PathAnchor
public typealias VectorContour = FlareCore.PathContour
public typealias AnchorKind = FlareCore.AnchorKind
/// An anchor by contour and index, ordered contour first; a handle end; what a pointer is over, a handle first.
public struct AnchorRef: Hashable, Comparable, Sendable {
    public var contour: Int, index: Int
    public init(contour: Int, index: Int) { (self.contour, self.index) = (contour, index) }
    public static func < (a: AnchorRef, b: AnchorRef) -> Bool { (a.contour, a.index) < (b.contour, b.index) }
}
public enum HandleEnd: String, Codable, Sendable { case handleIn = "in", handleOut = "out" }
public enum PathHit: Hashable, Sendable { case handle(AnchorRef, HandleEnd), anchor(AnchorRef), segment(FlareCore.PathLocation) }
/// The open Pen path, document space; `scale` is view points per document point at the latest press.
public struct PenDraft: Hashable, Sendable {
    public var contour: VectorContour, scale: Double
    public init(contour: VectorContour, scale: Double) { (self.contour, self.scale) = (contour, scale) }
}
/// The path whose points are edited, in its own space, and the matrix to document space.
public struct PathInEdit: Hashable, Sendable {
    public var id: String, path: VectorPath, toDocument: Matrix
    public init(id: String, path: VectorPath, toDocument: Matrix) { (self.id, self.path, self.toDocument) = (id, path, toDocument) }
}
/// A workspace the path commands run on. `pathHelp` says why edits can't run (no document, a locked layer); `addPath` adds a
/// selected path layer above the selection, one undo step; `setPath` replaces `pathInEdit`'s path, folding one `drag`'s steps.
public protocol PathEditTarget: Sendable {
    var penDraft: PenDraft? { get set }
    var pathInEdit: PathInEdit? { get }
    var anchorSelection: Selection<AnchorRef> { get set }
    var pathHelp: String? { get }
    mutating func addPath(_ path: VectorPath, name: String) throws -> String
    mutating func setPath(_ path: VectorPath, name: String, drag: String?) throws
}
