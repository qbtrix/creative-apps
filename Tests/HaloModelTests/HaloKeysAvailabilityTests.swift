// HaloKeysAvailabilityTests.swift: LK-6, QB-F1 for the keys area. The rows,
// stopwatch, diamond, Parent and Blend need a composition and a selected
// layer; the viewer drag needs only a composition (a drag selects what it
// hits). With those, each acts unless the service it calls says why not,
// and that reason comes through. Linux and macOS.
@testable import HaloModel
import Testing

private let keysCommands = HaloCommand.allCases.filter { $0.area == .keys }
private let viewerDragCommands: [HaloCommand] = [
    .beginViewerDrag(x: 10, y: 10), .moveViewerDrag(x: 20, y: 20), .endViewerDrag, .cancelViewerDrag,
]
private let inspectorCommands = keysCommands.filter { !viewerDragCommands.contains($0) }

/// A keying service that isn't ready, over the fake's behavior.
private struct UnreadyKeying: PropertyKeying {
    let fake = FakePropertyKeying()
    var unavailableHelp: String? { "Keying is resting." }
    func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow] {
        fake.rows(for: layerID, in: composition, at: frame)
    }
    func setValue(
        _ value: Double, for property: HaloProperty, of layerID: String, at frame: Int,
        in composition: inout HaloComposition
    ) throws {}
    func toggleAnimation(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws {}
    func toggleKey(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws {}
    func setParent(
        _ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws {}
}

/// A dragging service that isn't ready.
private struct UnreadyDragging: ViewerDragging {
    var unavailableHelp: String? { "Dragging is resting." }
    func hit(_ composition: HaloComposition, at frame: Int, point: HaloPoint) -> String? { nil }
    func commitMove(_ layerID: String, by delta: HaloPoint, at frame: Int, in composition: inout HaloComposition) throws {}
}

private func keyedProject(_ services: HaloServices, ball: Bool) -> HaloProject {
    var project = commandProject("keyed", services)
    if ball { project.selectLayer("comp-1-layer-2") }
    return project
}

@Test(arguments: [HaloServices.fake, .live])
func noCompositionTurnsEveryKeysCommandOff(_ services: HaloServices) {
    let project = HaloProject(services: services)
    for command in keysCommands {
        #expect(project.unavailableHelp(for: command) == "Create a composition first.", "\(command)")
    }
}

@Test(arguments: [HaloServices.fake, .live])
func noLayerTurnsTheInspectorOffButNotTheViewerDrag(_ services: HaloServices) {
    let project = keyedProject(services, ball: false)
    for command in inspectorCommands {
        #expect(project.unavailableHelp(for: command) == "Select a layer first.", "\(command)")
    }
    for command in viewerDragCommands {
        #expect(project.unavailableHelp(for: command) == nil, "\(command)")
    }
}

@Test(arguments: [HaloServices.fake, .live])
func everyKeysCommandActsWithALayer(_ services: HaloServices) {
    let project = keyedProject(services, ball: true)
    #expect(keysCommands.count == 11)
    for command in keysCommands {
        #expect(project.unavailableHelp(for: command) == nil, "\(command)")
    }
}

@Test func anUnreadyKeyingServiceSaysWhy() {
    var services = HaloServices.fake
    services.keying = UnreadyKeying()
    let project = keyedProject(services, ball: true)
    for command in inspectorCommands where command != .setBlendMode(.multiply) {
        #expect(project.unavailableHelp(for: command) == "Keying is resting.", "\(command)")
    }
    #expect(project.unavailableHelp(for: .setBlendMode(.multiply)) == nil)
    for command in viewerDragCommands {
        #expect(project.unavailableHelp(for: command) == nil, "\(command)")
    }
}

@Test func anUnreadyDraggingServiceSaysWhy() {
    var services = HaloServices.fake
    services.dragging = UnreadyDragging()
    for ball in [false, true] {
        let project = keyedProject(services, ball: ball)
        for command in viewerDragCommands {
            #expect(project.unavailableHelp(for: command) == "Dragging is resting.", "\(command)")
        }
    }
    #expect(keyedProject(services, ball: true).unavailableHelp(for: .toggleKey(.x)) == nil)
}
