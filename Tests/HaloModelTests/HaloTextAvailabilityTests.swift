// HaloTextAvailabilityTests.swift: TX-3, QB-F1 for the TEXT area. The text
// commands (field, size, end of a size scrub, layer color) answer state only
// on `.fake` and `.live`: no composition, then no layer or a non-text layer,
// say what they need; a text layer turns every one on; the layer color is
// also on for a solid or shape (HaloFillColorAvailabilityTests); none reads
// "Not built yet". Linux and macOS.
@testable import HaloModel
import Testing

/// Every command in the text area, so a new one is covered as it is added.
private let textCommands = HaloCommand.allCases.filter { $0.area == .text }

/// `name` loaded on `services`, the first composition selected, no layer.
private func textProject(_ name: String, _ services: HaloServices) throws -> HaloProject {
    var project = HaloProject(services: services)
    project.restore(try #require(HaloFixtures.project(name)))
    return project
}

/// `help` from every text command; `color` (default `help`) from the color row.
private func expectHelp(_ project: HaloProject, _ help: String?, color: String?? = .none, _ label: String = "") {
    for command in textCommands {
        let want = if case .setLayerColor = command { color ?? help } else { help }
        #expect(project.unavailableHelp(for: command) == want, "\(command) \(label)")
    }
}

private let noColorLayer = "Select a text, solid or shape layer first."


@Test func theTextAreaHasTheFieldSizeScrubAndColor() {
    #expect(textCommands.count == 4)
    #expect(textCommands.contains(.setText("Hello")))
    #expect(textCommands.contains(.setFontSize(48)))
    #expect(textCommands.contains(.endTextSizeScrub))
    #expect(textCommands.contains(.setLayerColor(HaloLayerColor(red: 1, green: 0, blue: 0))))
}

@Test(arguments: [HaloServices.fake, .live])
func noCompositionSaysCreateOne(services: HaloServices) {
    expectHelp(HaloProject(services: services), "Create a composition first.")
}

@Test(arguments: [HaloServices.fake, .live])
func noLayerOrANonTextLayerSaysSelectATextLayer(services: HaloServices) throws {
    var project = try textProject("empty", services)
    #expect(project.selectedLayer == nil)
    expectHelp(project, "Select a text layer first.", color: noColorLayer, "no layer")
    project.newLayer(.solid)
    #expect(project.selectedLayer?.name == "Solid 1")
    expectHelp(project, "Select a text layer first.", color: .some(nil), "on Solid 1")
    for kind in [HaloLayerKind.shape, .null] {
        project.newLayer(kind)
        #expect(project.selectedLayer?.kind == kind)
        expectHelp(project, "Select a text layer first.", color: kind == .null ? noColorLayer : .some(nil), "on \(kind)")
    }
}

@Test(arguments: [HaloServices.fake, .live])
func aTextLayerTurnsEveryTextCommandOn(services: HaloServices) throws {
    var project = try textProject("empty", services)
    project.newLayer(.solid)
    project.newLayer(.text)
    #expect(project.selectedLayer?.name == "Text 1")
    expectHelp(project, nil, "on Text 1")
    let solid = try #require(project.selectedComposition?.layers.first { $0.name == "Solid 1" })
    project.selectLayer(solid.id)
    expectHelp(project, "Select a text layer first.", color: .some(nil), "back on Solid 1")
}

@Test(arguments: [HaloServices.fake, .live])
func theFixturesTitleLayerCanBeEdited(services: HaloServices) throws {
    var project = try textProject("three-layers", services)
    let title = try #require(project.selectedComposition?.layers.first { $0.name == "Title" })
    project.selectLayer(title.id)
    expectHelp(project, nil, "on Title")
    let badge = try #require(project.selectedComposition?.layers.first { $0.name == "Badge" })
    project.selectLayer(badge.id)
    expectHelp(
        project, badge.kind == .text ? nil : "Select a text layer first.",
        color: badge.kind == .null ? noColorLayer : .some(nil), "on Badge")
}

@Test(arguments: [HaloServices.fake, .live])
func noTextCommandReadsNotBuiltYet(services: HaloServices) throws {
    var states = [HaloProject(services: services), try textProject("empty", services)]
    var project = try textProject("three-layers", services)
    for layer in project.selectedComposition?.layers ?? [] {
        project.selectLayer(layer.id)
        states.append(project)
    }
    for state in states {
        for command in textCommands {
            let help = state.unavailableHelp(for: command) ?? ""
            #expect(!help.contains("Not built yet") && !help.contains("isn't built yet"), "\(command): \(help)")
        }
    }
}
