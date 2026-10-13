// DesignInspectorContentTests.swift: the exact words Design's inspector header
// shows for a node and for a page, and which kinds have a fill row. Runs on
// Linux and macOS.
import DesignModel
import Foundation
import Testing

private func node(_ kind: DesignNodeKind = .rectangle, _ frame: DesignRect) -> DesignNode {
    DesignNode(id: "n", name: "Layer", kind: kind, frame: frame)
}

@Test func aNodesHeaderLinesAreItsKindAndWholePointSize() {
    #expect(node(.rectangle, rc(40, 40, 160, 120)).inspectorDetails == ["Rectangle", "160 × 120 pt"])
    #expect(node(.text, rc(0, 0, 120, 24)).inspectorDetails == ["Text", "120 × 24 pt"])
}

@Test func theKindLineIsTheKindsDefaultNameNotTheLayersOwnName() {
    var renamed = node(.ellipse, rc(0, 0, 10, 10))
    renamed.name = "Logo"
    #expect(renamed.inspectorDetails == ["Ellipse", "10 × 10 pt"])
    for kind in DesignNodeKind.allCases {
        #expect(node(kind, rc(0, 0, 1, 1)).inspectorDetails.first == kind.defaultName)
    }
}

@Test func aFractionalSizeRoundsToWholePointsLikeThePageSize() {
    #expect(node(.frame, rc(0, 0, 160.4, 119.6)).inspectorDetails == ["Frame", "160 × 120 pt"])
    #expect(node(.frame, rc(0, 0, 1.5, 2.5)).inspectorDetails == ["Frame", "2 × 3 pt"])
    #expect(node(.frame, rc(0, 0, 0.4, 0.4)).inspectorDetails == ["Frame", "0 × 0 pt"])
}

@Test func theSizeLineShowsNoPosition() {
    #expect(node(.group, rc(-300.5, 9000, 50, 60)).inspectorDetails == ["Group", "50 × 60 pt"])
}

@Test func aNonFiniteOrHugeSizeNeverTrapsAndStaysAPointSize() {
    #expect(node(.frame, rc(0, 0, .infinity, .nan)).inspectorDetails == ["Frame", "0 × 0 pt"])
    #expect(node(.frame, rc(0, 0, 1e300, -1e300)).inspectorDetails == ["Frame", "1000000000 × -1000000000 pt"])
}

@Test func aPagesHeaderLineIsItsFrameSize() throws {
    let workspace = openDesign()
    #expect(workspace.selectedPage?.inspectorDetails == ["Frame 1440 × 1024 pt"])
    let json = #"{"id":"p","name":"P","frameWidth":375.4,"frameHeight":811.6,"nodes":[]}"#
    let page = try JSONDecoder().decode(DesignPage.self, from: Data(json.utf8))
    #expect(page.inspectorDetails == ["Frame 375 × 812 pt"])
}

@Test func theHeaderFollowsTheSelectedNodeThroughAFrameEdit() throws {
    var workspace = openDesign()
    #expect(workspace.selectedNode == nil)
    workspace.selectItem("node-1")
    #expect(workspace.selectedNode?.inspectorDetails == ["Frame", "1440 × 1024 pt"])
    try workspace.setNodeFrame("node-1", x: 0, y: 0, width: 800.5, height: 600)
    #expect(workspace.selectedNode?.inspectorDetails == ["Frame", "801 × 600 pt"])
}

@Test func everyKindButAGroupHasAFillRowAndATextsIsItsColor() {
    #expect(DesignNodeKind.text.fillLabel == "Text Color")
    #expect(DesignNodeKind.group.fillLabel == nil)
    for kind in [DesignNodeKind.frame, .rectangle, .ellipse, .instance] { #expect(kind.fillLabel == "Fill") }
}
