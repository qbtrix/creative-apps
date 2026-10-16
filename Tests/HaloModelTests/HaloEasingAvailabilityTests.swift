// HaloEasingAvailabilityTests.swift: EZ-5 (#428), QB-F1 for the easing
// area. The Keyframe Easing commands and Delete Keyframes act once a key is
// picked (from the timeline or the EASING list) and say why not before; picking keys needs a layer (a lane click only
// a composition, since it selects the layer); an easing service that isn't
// ready says why. Linux and macOS.
@testable import HaloModel
import Testing

/// Why an easing edit waits: no key picked, from the timeline or a row.
private let noPick = "Click a key on the timeline or pick a span in the EASING list first."

/// The commands that change the picked keys' easing.
private let easingEdits: [HaloCommand] =
    HaloEasingPreset.allCases.map { HaloCommand.setEasing($0) } + [
        .setCustomEasing(.cubicBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1)), .moveEasingHandle(index: 0, x: 0.2, y: 0.1),
        .endEasingDrag,
    ]

private func picks(_ layerID: String) -> [HaloCommand] {
    [
        .selectKey(HaloKeyRef(layerID: layerID, property: .x, frame: 0), extending: false),
        .selectLaneKeys(layerID: layerID, frame: 0, extending: false), .clearKeySelection,
    ]
}

private func keyedBall(_ services: HaloServices) throws -> (project: HaloProject, ball: String) {
    let project = commandProject("keyed", services)
    let layers = try #require(project.selectedComposition).layers
    return (project, try #require(layers.first { $0.name == "Ball" }).id)
}

/// An easing service that isn't ready, over the fake's behavior.
private struct UnreadyEasing: KeyEasing {
    let fake = FakeKeyEasing()
    var unavailableHelp: String? { "Easing is resting." }
    func keys(of layerID: String, in composition: HaloComposition) -> [HaloKeyRef] {
        fake.keys(of: layerID, in: composition)
    }
    func easing(of key: HaloKeyRef, in composition: HaloComposition) -> HaloEasing? {
        fake.easing(of: key, in: composition)
    }
    func setEasing(_ easing: HaloEasing, on keys: Set<HaloKeyRef>, in composition: inout HaloComposition) throws {
        try fake.setEasing(easing, on: keys, in: &composition)
    }
}

@Test(arguments: [HaloServices.fake, .live])
func easingEditsWaitForAPickedKey(services: HaloServices) throws {
    var (project, ball) = try keyedBall(services)
    project.selectLayer(ball)
    for command in easingEdits {
        #expect(project.unavailableHelp(for: command) == noPick, "\(command)")
    }
    for command in picks(ball) {
        #expect(project.unavailableHelp(for: command) == nil, "\(command)")
    }
    project.selectKey(HaloKeyRef(layerID: ball, property: .x, frame: 0), extending: false)
    for command in easingEdits + picks(ball) {
        #expect(project.unavailableHelp(for: command) == nil, "\(command)")
    }
    project.clearKeySelection()
    #expect(project.unavailableHelp(for: .setEasing(.easeIn)) == noPick)
}

@Test(arguments: [HaloServices.fake, .live])
func easingNeedsALayerAndAComposition(services: HaloServices) throws {
    let (project, ball) = try keyedBall(services)
    #expect(project.selectedLayer == nil)
    for command in easingEdits + picks(ball) where !command.isLaneClick {
        #expect(project.unavailableHelp(for: command) == "Select a layer first.", "\(command)")
    }
    #expect(project.unavailableHelp(for: .selectLaneKeys(layerID: ball, frame: 0, extending: false)) == nil)
    let empty = HaloProject(services: services)
    #expect(empty.selectedComposition == nil)
    for command in easingEdits + picks(ball) {
        #expect(empty.unavailableHelp(for: command) == "Create a composition first.", "\(command)")
    }
}

@Test func anUnreadyEasingServiceSaysWhyAfterTheStateReasons() throws {
    var services = HaloServices.fake
    services.easing = UnreadyEasing()
    var (project, ball) = try keyedBall(services)
    #expect(project.unavailableHelp(for: .setEasing(.easeIn)) == "Select a layer first.")
    #expect(project.unavailableHelp(for: .selectLaneKeys(layerID: ball, frame: 0, extending: false))
        == "Easing is resting.")
    project.selectLayer(ball)
    for command in easingEdits + picks(ball) {
        #expect(project.unavailableHelp(for: command) == "Easing is resting.", "\(command)")
    }
}

/// B1: ⌫'s Delete Keyframes acts once a key is picked, and says how before.
@Test(arguments: [HaloServices.fake, .live])
func deleteKeysWaitsForAPickedKey(services: HaloServices) throws {
    var (project, ball) = try keyedBall(services)
    #expect(project.unavailableHelp(for: .deleteKeys) == "Select a layer first.")
    project.selectLayer(ball)
    #expect(project.unavailableHelp(for: .deleteKeys) == "Click a key on the timeline first.")
    project.selectLaneKeys(layerID: ball, frame: 24, extending: false)
    #expect(project.unavailableHelp(for: .deleteKeys) == nil)
}

extension HaloCommand {
    fileprivate var isLaneClick: Bool {
        if case .selectLaneKeys = self { return true }
        return false
    }
}
