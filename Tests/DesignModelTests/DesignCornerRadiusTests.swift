// DesignCornerRadiusTests.swift: the inspector's Radius row (#532, slice 1).
// setCornerRadius clamps to half the shorter side, a run of edits is one undo
// step, and cornerRadiusHelp says why the row is off: nothing selected, a kind
// with no corners, or a lock on the layer or a group around it. Old files with
// no radius still open. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DesignModel
import Testing

/// Desktop (node-1) holds a group (node-2) holding a 120 × 80 rectangle (node-3), and an ellipse (node-4).
private func sample() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(100, 100, 300, 200), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(120, 130, 120, 80), in: "node-2")
    try workspace.addNode(.ellipse, frame: rc(500, 100, 60, 60), in: "node-1")
    return workspace
}

@Test func theRadiusClampsToHalfTheShorterSide() throws {
    var workspace = try sample()
    try workspace.setCornerRadius("node-3", 12)
    #expect(workspace.treeNode("node-3")?.cornerRadius == 12)
    try workspace.setCornerRadius("node-3", 500)
    #expect(workspace.treeNode("node-3")?.cornerRadius == 40)
    try workspace.setCornerRadius("node-3", -5)
    #expect(workspace.treeNode("node-3")?.cornerRadius == 0)
    try workspace.setCornerRadius("node-3", 8)
    try workspace.setCornerRadius("node-3", .nan)
    try workspace.setCornerRadius("node-3", .infinity)
    #expect(workspace.treeNode("node-3")?.cornerRadius == 8)
    #expect(workspace.treeNode("node-3")?.maxCornerRadius == 40)
}

@Test func aShrunkLayerDrawsAtMostHalfItsShorterSide() throws {
    var workspace = try sample()
    try workspace.setCornerRadius("node-3", 30)
    try workspace.setNodeFrame("node-3", x: 120, y: 130, width: 120, height: 20)
    #expect(workspace.treeNode("node-3")?.drawnCornerRadius == 10)
}

@Test func aRunOfRadiusEditsIsOneUndoStep() throws {
    var workspace = try sample()
    let before = workspace.pages
    for radius in stride(from: 1.0, through: 20, by: 1) { try workspace.setCornerRadius("node-3", radius) }
    #expect(workspace.undoActionName == "Undo Change Corner Radius")
    workspace.undo()
    #expect(workspace.pages == before)
    workspace.redo()
    #expect(workspace.treeNode("node-3")?.cornerRadius == 20)
}

@Test func aFrameHasCornersToo() throws {
    var workspace = try sample()
    try workspace.setCornerRadius("node-1", 24)
    #expect(workspace.treeNode("node-1")?.cornerRadius == 24)
}

@Test func aShapeWithNoCornersRefusesARadius() throws {
    var workspace = try sample()
    let before = workspace
    #expect(throws: DesignTreeError.noCorners("node-4")) { try workspace.setCornerRadius("node-4", 10) }
    #expect(throws: DesignTreeError.noCorners("node-2")) { try workspace.setCornerRadius("node-2", 10) }
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.setCornerRadius("nope", 10) }
    #expect(workspace == before)
}

@Test func aLockedLayerOrOneInALockedGroupRefusesARadius() throws {
    var workspace = try sample()
    try workspace.setNodeLocked("node-2", true)
    let before = workspace
    #expect(throws: DesignTreeError.locked("node-3")) { try workspace.setCornerRadius("node-3", 10) }
    #expect(workspace == before)
}

@Test func theRadiusRowSaysWhyItIsOff() throws {
    var workspace = try sample()
    workspace.deselect()
    #expect(workspace.cornerRadiusHelp == "Select a rectangle or frame to round its corners.")
    workspace.selectItem("node-3")
    #expect(workspace.cornerRadiusHelp == nil)
    workspace.selectItem("node-4")
    #expect(workspace.cornerRadiusHelp == "An ellipse has no corners to round.")
    workspace.selectItem("node-2")
    #expect(workspace.cornerRadiusHelp == "A group has no corners to round.")
    try workspace.setNodeLocked("node-2", true)
    workspace.selectItem("node-3")
    #expect(workspace.cornerRadiusHelp == "Unlock the group around this layer to edit it.")
    try workspace.setNodeLocked("node-1", true)
    workspace.selectItem("node-1")
    #expect(workspace.cornerRadiusHelp == "Unlock the layer to edit it.")
    #expect(DesignNodeKind.text.cornerlessHelp == "Text has no corners to round.")
    #expect(DesignNodeKind.rectangle.cornerlessHelp == nil && DesignNodeKind.frame.cornerlessHelp == nil)
}

@Test func aFileWithoutARadiusStillOpensWithSquareCorners() throws {
    let old = #"""
        {"pages":[{"frameHeight":100,"frameWidth":100,"id":"page-1","name":"Page 1","nodes":[
        {"children":[],"fill":{"blue":0,"green":0,"red":0},"frame":{"height":10,"width":10,"x":0,"y":0},
        "id":"node-1","isHidden":false,"isLocked":false,"kind":"rectangle","name":"R","text":""}]}],"version":1}
        """#
    var workspace = DesignWorkspace()
    try workspace.open(Data(old.utf8))
    #expect(workspace.treeNode("node-1")?.cornerRadius == 0)
}

@Test func theRadiusSurvivesSaveAndOpen() throws {
    var workspace = try sample()
    try workspace.setCornerRadius("node-3", 16)
    var reopened = DesignWorkspace()
    try reopened.open(try workspace.fileData())
    #expect(reopened.treeNode("node-3")?.cornerRadius == 16)
}

@Test func aFileWithANegativeRadiusIsRefused() throws {
    let bad = #"""
        {"pages":[{"frameHeight":100,"frameWidth":100,"id":"page-1","name":"Page 1","nodes":[
        {"children":[],"cornerRadius":-1,"fill":{"blue":0,"green":0,"red":0},"frame":{"height":10,"width":10,"x":0,"y":0},
        "id":"node-1","isHidden":false,"isLocked":false,"kind":"rectangle","name":"R","text":""}]}],"version":1}
        """#
    var workspace = DesignWorkspace()
    #expect(throws: DesignFileError.invalidNumber("node-1")) { try workspace.open(Data(bad.utf8)) }
}
