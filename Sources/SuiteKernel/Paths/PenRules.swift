// PenRules.swift (pen-paths PN-1 stubs returning the draft, PN-5 bodies): Flare's Pen rules in the kernel. A press within
// `anchorTolerance` on screen of the last anchor adds nothing; three or more anchors close at `closeDistance`, inclusive.
public enum PenRules {
    /// View points: how near the first anchor a press closes, and how near the last one it adds nothing.
    public static let closeDistance = 4.0, anchorTolerance = 1.0
    public static let degenerate = "Click at least two separate places to draw a path."
    public static let notBuilt = CatalogError.notBuilt(id: "path", feature: "pen-paths PN-7")
    /// The draft after a press at `point`, with a drag's `handleOut`.
    public static func add(_ point: Point, handleOut: Point?, to draft: PenDraft?, scale: Double) -> PenDraft {
        draft ?? PenDraft(contour: VectorContour(anchors: [], closed: false), scale: scale)
    }
    public static func closes(_ point: Point, _ draft: PenDraft) -> Bool { false }
    public static func closed(_ draft: PenDraft) -> PenDraft { draft }
    public static func finishHelp(_ draft: PenDraft?) -> String? { nil }
    /// Why Finish can't end the draft, nil when it can; the draft as a path, throwing `degenerate` when too small to see.
    public static func path(_ draft: PenDraft) throws -> VectorPath { VectorPath(contours: [draft.contour]) }
}
