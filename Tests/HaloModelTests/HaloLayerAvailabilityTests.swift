// HaloLayerAvailabilityTests.swift: LP-2, QB-F1 for the Layer menu.
// Duplicate, Rename…, Delete, Bring Forward and Send Backward are on exactly
// when they act and say why when they can't, on `.fake` and `.live`; rename,
// move and pick need a layer the composition has; each edit's Undo title
// names it. Linux and macOS.
@testable import HaloModel
import Testing

private let fiveCommands: [HaloCommand] = [
    .duplicateLayer, .beginRenameLayer, .deleteLayer, .bringLayerForward, .sendLayerBackward,
]

/// `three-layers` (Title, Badge, Background, Rig) on `services`, `select` selected.
private func threeLayers(_ services: HaloServices, select: String?) throws -> HaloProject {
    var project = HaloProject(services: services)
    project.restore(try #require(HaloFixtures.project("three-layers")))
    if let select { project.selectLayer(try id(select, in: project)) }
    return project
}

private func id(_ name: String, in project: HaloProject) throws -> String {
    try #require(project.selectedComposition?.layers.first { $0.name == name }).id
}

@Test(arguments: [HaloServices.fake, .live])
func noCompositionTurnsTheLayerCommandsOff(services: HaloServices) {
    let none = HaloProject(services: services)
    for command in fiveCommands + [.newLayer(.solid), .renameLayer("x", "A"), .moveLayer("x", to: 0)] {
        #expect(none.unavailableHelp(for: command) == "Create a composition first.", "\(command)")
    }
}

@Test(arguments: [HaloServices.fake, .live])
func noLayerSelectedSaysSelectALayer(services: HaloServices) throws {
    var empty = HaloProject(services: services)
    empty.restore(try #require(HaloFixtures.project("empty")))
    for command in fiveCommands {
        #expect(empty.unavailableHelp(for: command) == "Select a layer first.", "\(command)")
    }
    #expect(empty.unavailableHelp(for: .newLayer(.text)) == nil)
    let unselected = try threeLayers(services, select: nil)
    for command in fiveCommands {
        #expect(unselected.unavailableHelp(for: command) == "Select a layer first.", "\(command)")
    }
}

@Test(arguments: [HaloServices.fake, .live])
func aMiddleLayerCanDoAllFive(services: HaloServices) throws {
    let project = try threeLayers(services, select: "Badge")
    for command in fiveCommands + [.newLayer(.solid)] {
        #expect(project.unavailableHelp(for: command) == nil, "\(command)")
    }
    let badge = try id("Badge", in: project)
    #expect(project.unavailableHelp(for: .renameLayer(badge, "")) == nil)
    #expect(project.unavailableHelp(for: .moveLayer(badge, to: 3)) == nil)
    #expect(project.unavailableHelp(for: .selectLayer(badge)) == nil)
    #expect(project.unavailableHelp(for: .renameLayer("gone", "A")) == "That layer no longer exists.")
    #expect(project.unavailableHelp(for: .moveLayer("gone", to: 0)) == "That layer no longer exists.")
}

@Test(arguments: [HaloServices.fake, .live])
func theEndsSayWhyTheyCantMove(services: HaloServices) throws {
    let top = try threeLayers(services, select: "Title")
    #expect(top.unavailableHelp(for: .bringLayerForward) == "This layer is already at the top.")
    #expect(top.unavailableHelp(for: .sendLayerBackward) == nil)
    let bottom = try threeLayers(services, select: "Rig")
    #expect(bottom.unavailableHelp(for: .sendLayerBackward) == "This layer is already at the bottom.")
    #expect(bottom.unavailableHelp(for: .bringLayerForward) == nil)
}

@Test(arguments: [HaloServices.fake, .live])
func noLayerCommandIsAStub(services: HaloServices) throws {
    let states = [HaloProject(services: services), try threeLayers(services, select: nil),
                  try threeLayers(services, select: "Badge")]
    for state in states {
        for command in HaloCommand.allCases + [.selectLayer(nil)] where command.area == .layers {
            let help = state.unavailableHelp(for: command)
            #expect(help?.contains("Not built yet") != true, "\(command): \(help ?? "")")
            #expect(help.map { !$0.isEmpty } ?? true, "\(command)")
        }
    }
}

@Test func eachEditNamesItsUndo() throws {
    var project = try threeLayers(.fake, select: "Badge")
    project.duplicateSelectedLayer()
    #expect(project.title(for: .undo) == "Undo Duplicate Layer")
    let copy = try #require(project.selectedLayer).id
    project.renameLayer(copy, to: "Badge 2")
    #expect(project.title(for: .undo) == "Undo Rename Layer")
    project.moveLayer(copy, to: 4)
    #expect(project.title(for: .undo) == "Undo Move Layer")
    project.bringSelectedLayerForward()
    #expect(project.title(for: .undo) == "Undo Move Layer")
    project.deleteSelectedLayer()
    #expect(project.title(for: .undo) == "Undo Delete Layer")
    #expect(project.selectedComposition?.layers.map(\.name) == ["Title", "Badge", "Background", "Rig"])
}

@Test func layerMenuReasonsReadAsTheMenuSaysThem() throws {
    let bottom = try threeLayers(.fake, select: "Rig")
    #expect(bottom.layerMenuReasons.split(separator: "\n") == [
        "Duplicate", "Rename…", "Delete", "Bring Forward", "Send Backward: This layer is already at the bottom.",
    ])
    let none = try threeLayers(.fake, select: nil)
    #expect(none.layerMenuReasons.split(separator: "\n").last == "Send Backward: Select a layer first.")
    #expect(none.layerMenuReasons.contains("Delete: Select a layer first."))
}
