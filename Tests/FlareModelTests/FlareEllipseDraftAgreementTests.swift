// FlareEllipseDraftAgreementTests.swift: adversarial checks that the Ellipse
// tool's live draft and its commit agree (#471): whenever `dragChanged` shows
// a draft, the same `drag` adds exactly one layer, and whenever it shows none,
// the drag adds nothing. Covers no document, odd boxes and mid-drag state
// changes. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func agree(_ workspace: FlareWorkspace, _ start: Point, _ end: Point) -> Bool {
    var w = workspace
    w.dragChanged(from: start, to: end)
    let previewed = w.draft != nil
    let before = w.layers.count
    w.drag(from: start, to: end)
    return w.draft == nil && (w.layers.count == before + 1) == previewed
        && w.layers.count - before <= 1
}

private let boxes: [(Point, Point)] = [
    (Point(x: 0, y: 0), Point(x: 50, y: 50)),
    (Point(x: 0, y: 0), Point(x: 0, y: 0)),
    (Point(x: 0, y: 0), Point(x: 0.999, y: 50)),
    (Point(x: 0, y: 0), Point(x: 1, y: 1)),
    (Point(x: 50, y: 50), Point(x: -50, y: -50)),
    (Point(x: .nan, y: 0), Point(x: 10, y: 10)),
    (Point(x: .infinity, y: 0), Point(x: .infinity, y: 10)),
    (Point(x: -.greatestFiniteMagnitude, y: 0), Point(x: .greatestFiniteMagnitude, y: 10)),
    (Point(x: -1e300, y: -1e300), Point(x: 1e300, y: 1e300)),
]

@Test(arguments: [false, true])
func ellipseDraftMatchesCommitForOddBoxes(hasDocument: Bool) {
    var workspace = FlareWorkspace()
    if hasDocument { workspace.newDocument() }
    workspace.selectTool(.ellipse)
    for (start, end) in boxes {
        #expect(agree(workspace, start, end), "box \(start) → \(end), document: \(hasDocument)")
    }
}

@Test func ellipseDraftMatchesCommitOnTheSampleAnimation() {
    var workspace = FlareWorkspace()
    workspace.newSampleAnimation()
    workspace.selectTool(.ellipse)
    for (start, end) in boxes {
        #expect(agree(workspace, start, end), "box \(start) → \(end)")
    }
}

@Test func ellipseDraftMatchesCommitOverSeededRandomDrags() {
    var rng = SplitMix(seed: 471)
    var workspace = FlareWorkspace()
    workspace.selectTool(.ellipse)
    for i in 0..<400 {
        if i == 200 { workspace.newDocument() }
        let start = Point(x: rng.coordinate(), y: rng.coordinate())
        let end = Point(x: rng.coordinate(), y: rng.coordinate())
        #expect(agree(workspace, start, end), "drag \(i): \(start) → \(end)")
    }
}

@Test func otherToolsNeverDraftWithOrWithoutADocument() {
    for tool in FlareTool.allCases where tool != .ellipse {
        var workspace = FlareWorkspace()
        workspace.selectTool(tool)
        workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
        #expect(workspace.draft == nil)
        workspace.newDocument()
        workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
        #expect(workspace.draft == nil)
    }
}

@Test func aRefusedDragAfterADraftLeavesNoDraftAndNoLayer() {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
    #expect(workspace.draft != nil)
    // The pointer comes back to the start before release: the drag is a click.
    workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 0.2, y: 0.2))
    #expect(workspace.draft == nil)
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 0.2, y: 0.2))
    #expect(workspace.draft == nil)
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test func openingADocumentMidDragDropsTheDraft() {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
    workspace.newSampleAnimation()
    #expect(workspace.draft == nil)
}

@Test func switchingToolMidDragDropsTheDraftAndTheReleaseAddsNothing() {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    workspace.dragChanged(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
    workspace.selectTool(.select)
    #expect(workspace.draft == nil)
    workspace.drag(from: Point(x: 0, y: 0), to: Point(x: 50, y: 50))
    #expect(workspace.layers.isEmpty)
}

/// A small deterministic generator, so a failure names a reproducible drag.
private struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// Mostly ordinary stage coordinates, sometimes sub-point jitter or extremes.
    mutating func coordinate() -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        switch next() % 8 {
        case 0: return unit * 2 - 1
        case 1: return (unit * 2 - 1) * 1e12
        default: return (unit * 2 - 1) * 2000
        }
    }
}
