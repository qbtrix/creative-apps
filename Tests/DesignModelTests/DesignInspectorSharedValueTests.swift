// DesignInspectorSharedValueTests.swift: the inspector's value over several
// layers: the value they all share, or nil ("Mixed") when they differ; the
// opacity row's percent text; the Text rows' style over the selected text
// layers only (sharedTextStyle); and the hint the value column shows when the
// selection can't be edited (#276). On `cards`. Runs on Linux and macOS.
import DesignModel
import Testing

/// `cards` on the fake services (so opacity can be set), with A (node-2, 100 100 100 × 80) and
/// B (node-3, 300 140 200 × 80) selected, B primary.
private func cardsWithAAndB() -> DesignWorkspace {
    var workspace = DesignFixtures.cards
    workspace.useServices(.fake)
    workspace.selectItem("node-2")
    workspace.toggleSelection("node-3")
    return workspace
}

extension DesignWorkspace {
    /// Sets node `id`'s opacity through the style row, then puts the selection back as it was.
    fileprivate mutating func setOpacity(_ id: String, _ opacity: Double) throws {
        let selected = selectedNodeIDs
        selectItem(id)
        try setStyle(.opacity(opacity))
        deselect()
        for id in selected { toggleSelection(id) }
    }
}

@Test func aSharedValueIsTheOneEverySelectedLayerHas() {
    let workspace = cardsWithAAndB()
    #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
    #expect(workspace.sharedValue(\.frame.height) == 80)
    #expect(workspace.sharedValue(\.kind) == .rectangle)
}

@Test func aValueTheLayersDifferInIsMixed() {
    let workspace = cardsWithAAndB()
    #expect(workspace.sharedValue(\.frame.x) == nil)
    #expect(workspace.sharedValue(\.frame.width) == nil)
    #expect(workspace.sharedValue(\.name) == nil)
}

@Test func aDifferenceInAnyLaterLayerIsMixedNotTheFirstLayersValue() throws {
    var workspace = cardsWithAAndB()
    workspace.toggleSelection("node-4")
    #expect(workspace.selectedNodeIDs.count == 3)
    // A and B share H 80; C is 120 tall, so the row is Mixed however the layers are ordered.
    #expect(workspace.sharedValue(\.frame.height) == nil)
    try workspace.setNodeFrame("node-4", x: 700, y: 100, width: 100, height: 80)
    #expect(workspace.sharedValue(\.frame.height) == 80)
}

@Test func oneSelectedLayersValueIsShared() {
    var workspace = DesignFixtures.cards
    workspace.selectItem("node-2")
    #expect(workspace.sharedValue(\.frame.x) == 100)
    #expect(workspace.sharedValue(\.opacity) == 1)
    #expect(workspace.opacityPercentText == "100%")
}

@Test func withNothingSelectedThereIsNoSharedValue() {
    var workspace = DesignFixtures.cards
    #expect(workspace.selectedNodeIDs.isEmpty)
    #expect(workspace.sharedValue(\.frame.height) == nil)
    #expect(workspace.sharedValue(\.opacity) == nil)
    #expect(workspace.opacityPercentText == nil)
    workspace.selectItem("node-2")
    workspace.deselect()
    #expect(workspace.sharedValue(\.opacity) == nil)
}

@Test func theOpacityTextIsTheSharedPercentAndMixedOnceOneLayerChanges() throws {
    var workspace = cardsWithAAndB()
    #expect(workspace.opacityPercentText == "100%")
    try workspace.setOpacity("node-3", 0.5)
    #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
    #expect(workspace.sharedValue(\.opacity) == nil)
    #expect(workspace.opacityPercentText == nil)
    try workspace.setOpacity("node-2", 0.5)
    #expect(workspace.opacityPercentText == "50%")
}

@Test func theOpacityTextRoundsToAWholePercent() throws {
    var workspace = cardsWithAAndB()
    workspace.selectItem("node-2")
    for (opacity, text) in [(0.496, "50%"), (0.494, "49%"), (0.005, "1%"), (0.004, "0%"), (0, "0%"), (1, "100%"), (0.25, "25%")] {
        try workspace.setOpacity("node-2", opacity)
        #expect(workspace.sharedValue(\.opacity) == opacity)
        #expect(workspace.opacityPercentText == text, "\(opacity)")
    }
}

@Test func theLockedHintNamesTheLayerOnEveryRow() throws {
    var workspace = DesignFixtures.cards
    workspace.selectItem("node-2")
    for property in DesignStyleProperty.allCases {
        #expect(workspace.styleHint(property) == workspace.styleHelp(property), "\(property)")
    }
    try workspace.setNodeLocked("node-2", true)
    #expect(workspace.selectedNodeIDs == ["node-2"])
    for property in DesignStyleProperty.allCases {
        #expect(workspace.styleHint(property) == "Unlock A to change it.", "\(property)")
        #expect(workspace.styleHint(property) == DesignRefusal.locked("A").help)
    }
}

@Test func theHiddenHintNamesTheLayerOnEveryRow() {
    var workspace = DesignFixtures.cards
    workspace.selectItem("node-10")
    #expect(workspace.selectedNode?.name == "Hidden")
    for property in DesignStyleProperty.allCases {
        #expect(workspace.styleHint(property) == "Show Hidden to change it.", "\(property)")
    }
}

@Test func aLockOrHideOnTheGroupAroundTheLayerNamesThatLayer() throws {
    var workspace = DesignFixtures.cards
    workspace.selectItem("node-7")
    try workspace.setNodeLocked("node-6", true)
    #expect(workspace.styleHint(.opacity) == "Unlock E1 to change it.")
    try workspace.setNodeLocked("node-6", false)
    try workspace.setNodeHidden("node-6", true)
    #expect(workspace.styleHint(.opacity) == "Show E1 to change it.")
}

@Test func aLockedLayerAmongSeveralSelectedNamesItAndLockedWinsOverHidden() throws {
    var workspace = cardsWithAAndB()
    #expect(workspace.styleHint(.opacity) == nil)
    #expect(workspace.styleHelp(.opacity) == nil)
    try workspace.setNodeHidden("node-2", true)
    #expect(workspace.styleHint(.opacity) == "Show A to change it.")
    try workspace.setNodeLocked("node-3", true)
    #expect(workspace.styleHint(.opacity) == "Unlock B to change it.")
}

@Test func withNothingSelectedTheHintIsTheRowsHelp() {
    let workspace = DesignFixtures.cards
    #expect(workspace.styleHint(.opacity) == "Select a layer first.")
    #expect(workspace.styleHint(.opacity) == workspace.styleHelp(.opacity))
}

/// Title at 32 pt, Bold, Center: the style Title is given on `.live`.
private let boldTitle = DesignTextStyle(family: "System", size: 32, weight: 700, alignment: .center)

/// `cards` on `.live` with Title (node-5) set to `boldTitle`.
private func cardsWithBoldTitle() throws -> DesignWorkspace {
    var workspace = DesignFixtures.cards
    workspace.useServices(.live)
    workspace.selectItem("node-5")
    try workspace.setStyle(.textStyle(boldTitle))
    return workspace
}

@Test func theTextStyleLeavesOutLayersThatAreNotText() throws {
    var workspace = try cardsWithBoldTitle()
    workspace.toggleSelection("node-2")
    #expect(workspace.selectedNodeIDs == ["node-5", "node-2"])
    #expect(workspace.sharedValue(\.textStyle) == nil)
    #expect(workspace.sharedTextStyle == boldTitle)
}

@Test func twoTextLayersThatDifferReadMixedAndNoTextLayerReadsNothing() throws {
    var workspace = try cardsWithBoldTitle()
    let added = try workspace.addNode(.text, frame: DesignRect(x: 400, y: 40, width: 120, height: 24))
    #expect(workspace.sharedTextStyle == .default)
    workspace.selectItem("node-5")
    workspace.toggleSelection(added)
    #expect(workspace.sharedTextStyle == nil)
    workspace.selectItem("node-2")
    workspace.toggleSelection("node-3")
    #expect(workspace.sharedTextStyle == nil)
}
