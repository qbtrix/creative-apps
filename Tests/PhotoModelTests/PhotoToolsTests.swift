// PhotoToolsTests.swift: the no-dead-tools check for Photo's palette (QB-F1).
// On the `.fake` services every PhotoTool's drag on the `sample` fixture
// changes what that tool shows; on `.live` each tool's drag on an open canvas
// either changes it or the tool has help (`toolHelp`) saying why it can't yet.
// Each drag ends (`endDrag()`, the mouse-up) before the check, and the check
// reads only what the tool visibly changes (`shows`), never the whole
// workspace: an unfinished drag or a sampled clone source alone would make
// any two workspaces differ. Clone and heal sample their source with an
// Option press first, as a person does, then drag somewhere else. When a tool
// needs more under the pointer to show its effect, grow the fixture, never
// weaken the check. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

/// Whether `tool` visibly changed from `a` to `b`: the pixels for the
/// painting tools, the selection or the drawn outline for the area tools, the pending crop for crop, the
/// layers' offsets for move, the brush color for the eyedropper, the open
/// box for the Type tool and the draft or paths for the Pen.
private func shows(_ tool: PhotoTool, changeFrom a: PhotoWorkspace, to b: PhotoWorkspace) -> Bool {
    switch tool {
    case .brush, .eraser, .clone, .heal, .gradient, .bucket, .spotHeal, .remove:
        a.pixels != b.pixels
    case .marquee, .ellipse, .lasso, .polygon, .wand:
        a.selection != b.selection || a.selectionMask != b.selectionMask || a.areaDraft != b.areaDraft
    case .crop:
        a.pendingCrop != b.pendingCrop
    case .move:
        a.layers.map { [$0.offsetX, $0.offsetY] } != b.layers.map { [$0.offsetX, $0.offsetY] }
    case .eyedropper:
        a.brushOptions != b.brushOptions
    case .text:
        a.textBox != b.textBox
    case .pen:
        a.penDraft != b.penDraft || a.paths != b.paths
    }
}

/// Picks `tool` and, for clone and heal, samples the source with an Option
/// press at `source` and lifts the pointer, so the next drag stamps.
private func ready(_ workspace: inout PhotoWorkspace, _ tool: PhotoTool, source: Mask.Point) {
    workspace.selectTool(tool)
    guard tool == .clone || tool == .heal else { return }
    workspace.drag(from: source, to: source, modifiers: [.option])
    workspace.endDrag()
}

/// One whole drag: press at `start`, move to `end`, lift. The lasso bends
/// through (`end.x`, `start.y`) on the way, so its path has an area.
private func stroke(_ workspace: inout PhotoWorkspace, from start: Mask.Point, to end: Mask.Point) {
    if workspace.tool == .lasso { workspace.drag(from: start, to: Mask.Point(x: end.x, y: start.y), modifiers: []) }
    workspace.drag(from: start, to: end, modifiers: [])
    workspace.endDrag()
}

@Test(arguments: PhotoTool.allCases)
func photoToolActsOnFakeServices(_ tool: PhotoTool) throws {
    var before = try PhotoWorkspace.fixture(.sample)
    // The source is in the sky, the drag from the sun's edge into it, so a stamp
    // shows and a spot heal at the press has an edge to rebuild.
    ready(&before, tool, source: Mask.Point(x: 300, y: 100))
    // A tool not built yet has its own help (not a service's) on every service: it is disabled, not dead.
    if tool != .eyedropper, let help = tool.unavailableHelp { return #expect(before.toolHelp(tool) == help) }
    #expect(before.toolHelp(tool) == nil, "\(tool) has help on .fake, where every service works")
    var after = before
    stroke(&after, from: Mask.Point(x: 475, y: 220), to: Mask.Point(x: 600, y: 260))
    #expect(!after.isDragging, "\(tool)'s drag is still under way after endDrag")
    let changed = shows(tool, changeFrom: before, to: after)
    #expect(changed, "\(tool)'s drag on the sample changes nothing it shows on .fake")
}

@Test(arguments: PhotoTool.allCases)
func photoToolActsOrHasHelpOnLiveServices(_ tool: PhotoTool) throws {
    var before = PhotoWorkspace()
    try before.newCanvas(width: 64, height: 64)
    // A black line on the white canvas gives clone and heal a texture to copy; a
    // black dot under the press gives spot heal and remove something to take away,
    // and the bucket a region to fill red.
    before.selectTool(.brush)
    stroke(&before, from: Mask.Point(x: 4, y: 12), to: Mask.Point(x: 28, y: 12))
    stroke(&before, from: Mask.Point(x: 30, y: 30), to: Mask.Point(x: 30, y: 30))
    before.setToolOption(.color(red: 255, green: 0, blue: 0))
    ready(&before, tool, source: Mask.Point(x: 16, y: 8))
    var after = before
    stroke(&after, from: Mask.Point(x: 30, y: 30), to: Mask.Point(x: 50, y: 50))
    let changed = shows(tool, changeFrom: before, to: after)
    #expect(changed || before.toolHelp(tool)?.isEmpty == false, "\(tool) is dead on .live with no help saying why")
}

/// The Gradient tool is in the palette and enabled on both services (PG-3):
/// a drag draws into the selected layer as one "Gradient" step.
@Test func theGradientToolDrawsOnADrag() throws {
    #expect(PhotoTool.allCases.contains(.gradient))
    #expect(PhotoTool.gradient.unavailableHelp == nil)
    #expect(PhotoTool.gradient.isEnabled)
    #expect(PhotoWorkspace().toolHelp(.gradient) == nil)
    #expect(PhotoWorkspace(services: .fake).toolHelp(.gradient) == nil)
    var workspace = try PhotoWorkspace.fixture(.sample)
    let before = workspace
    workspace.selectTool(.gradient)
    stroke(&workspace, from: Mask.Point(x: 520, y: 180), to: Mask.Point(x: 600, y: 260))
    #expect(workspace.pixels != before.pixels && !workspace.isDragging)
    #expect(workspace.historySteps.count == before.historySteps.count + 1)
    #expect(workspace.undoActionName == "Undo Gradient")
}

/// The palette's tools are the catalog's `tool.` commands, each in the id
/// ledger.
@Test func theToolCommandIDsMatchTheCatalog() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/photo.txt")
    let ledger = Set(try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init))
    let ids = PhotoWorkspace.catalog.ids.filter { $0.hasPrefix("tool.") }
    #expect(Set(ids) == Set(PhotoTool.allCases.map { "tool.\($0.rawValue)" }))
    #expect(ids.filter { !ledger.contains($0) } == [], "every tool id is in the ledger")
}

/// The Gradient tool's `Fill` starts black to white, linear, and changes only
/// through `setGradient`, which leaves the brush's settings alone.
@Test func theGradientOptionChangesOnlyThroughItsSetter() {
    var options = ToolOptions()
    #expect(options.gradient == ToolOptions.defaultGradient)
    options.setGradient(.radial(stops: ToolOptions.defaultGradient.stops, center: .init(x: 0.5, y: 0.5), radius: 0.5))
    let radial = options.gradient
    if case .radial(_, _, let radius) = radial { #expect(radius == 0.5) } else { Issue.record("setGradient didn't take the radial fill") }
    #expect(radial.stops == ToolOptions.defaultGradient.stops)
    #expect(options.settings == ToolOptions().settings && options.red == 0)
}

/// The Move tool's transform rows show only while a picked layer can move:
/// on an adjustment layer they would sit disabled under the refusal, their
/// labels too faint to read (#2593). A picked image layer beside it still moves.
@Test func moveOptionsShowOnlyForAMovableSelection() throws {
    var workspace = try PhotoWorkspace.fixture(.layered)
    workspace.selectTool(.move)
    let background = try #require(workspace.layers.first { $0.name == "Background" })
    let curves = try #require(workspace.layers.first { $0.name == "Curves 1" })
    workspace.selectLayer(background.id)
    #expect(workspace.canMoveSelection)
    workspace.selectLayer(curves.id)
    #expect(!workspace.canMoveSelection)
    #expect(workspace.moveHint == "Select an image layer in the sidebar to move it.")
    workspace.pickLayer(background.id, .toggle)
    #expect(workspace.canMoveSelection)
    #expect(workspace.moveHint == "Drag over the image to move the selected layer.")
}

/// Move refuses an adjustment layer, which has no origin on the canvas, and
/// says why in the status and in its hint (#1630); an image layer moves.
@Test func moveRefusesAnAdjustmentLayerAndSaysWhy() throws {
    var workspace = try PhotoWorkspace.fixture(.layered)
    workspace.selectTool(.move)
    let background = try #require(workspace.layers.first { $0.name == "Background" })
    workspace.selectLayer(background.id)
    #expect(workspace.moveHint == "Drag over the image to move the selected layer.")
    let curves = try #require(workspace.layers.first { $0.name == "Curves 1" })
    workspace.selectLayer(curves.id)
    #expect(workspace.moveHint == "Select an image layer in the sidebar to move it.")
    let steps = workspace.historySteps.count
    stroke(&workspace, from: Mask.Point(x: 100, y: 100), to: Mask.Point(x: 150, y: 150))
    let after = try #require(workspace.layers.first { $0.id == curves.id })
    #expect(after.offsetX == curves.offsetX)
    #expect(after.offsetY == curves.offsetY)
    #expect(workspace.historySteps.count == steps)
    #expect(workspace.statusMessage == "Select an image layer in the sidebar to move it.")
}
