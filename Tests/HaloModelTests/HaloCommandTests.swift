// HaloCommandTests.swift: QB-F1, no dead controls. Every command is enabled
// or disabled with a reason, on `.fake` and `.live`; the shipped commands
// stay on when the state allows; a stub's reason names its area's issue. No
// test here pins an unbuilt command off, so a feature that turns its area on
// never edits this file (its own test asserts its commands). Linux and macOS.
@testable import HaloModel
import SuiteKernel
import Testing

/// `name` loaded on `services`, the first composition selected, no layer.
func commandProject(_ name: String, _ services: HaloServices) -> HaloProject {
    var project = HaloProject(services: services)
    if let state = HaloFixtures.project(name) { project.restore(state) }
    return project
}

/// The issues a stub may name for each area while it is not built.
let stubIssues: [HaloCommandArea: Set<String>] = [
    .playback: ["37"], .keys: ["38"], .layers: ["770"], .history: ["208"], .files: ["209"], .easing: ["428"],
    .render: ["451", "429"], .text: ["430"],
]

/// The stubs a feature packet's contract slice ships, named by task (key-editing KE-1).
let stubTasks: [HaloCommandArea: Set<String>] = [.easing: ["Not built yet (KE-3).", "Not built yet (KE-4)."]]

/// Commands that work today and answer from state only.
let shippedCommands: [HaloCommand] = [
    .newComposition, .duplicateComposition, .deleteComposition, .selectComposition("comp-1"),
    .renameComposition("comp-1", "Intro"), .newLayer(.solid), .selectLayer("comp-1-layer-2"), .setInPoint,
    .setOutPoint, .scrub(12),
]

@Test(arguments: [HaloServices.fake, .live])
func everyCommandActsOrSaysWhy(services: HaloServices) {
    var project = commandProject("keyed", services)
    var states = [project, HaloProject(services: services)]
    project.selectLayer("comp-1-layer-2")
    states.append(project)
    for state in states {
        for command in HaloCommand.allCases {
            let help = state.unavailableHelp(for: command)
            #expect(help.map { !$0.isEmpty } ?? true, "\(command) is disabled with no help")
            guard let help, help.hasPrefix("Not built yet"), stubTasks[command.area]?.contains(help) != true else { continue }
            let issue = help.dropFirst("Not built yet (#".count).dropLast(2)
            #expect(help == "Not built yet (#\(issue)).", "\(command): \(help)")
            #expect(stubIssues[command.area]?.contains(String(issue)) == true, "\(command) names #\(issue)")
        }
    }
}

@Test func allCasesListsEachCaseOnceInEveryArea() {
    #expect(Set(HaloCommand.allCases).count == HaloCommand.allCases.count)
    #expect(HaloCommand.allCases.count == 62)
    #expect(Set(HaloCommand.allCases.map(\.area)) == Set(HaloCommandArea.allCases))
    #expect(HaloCommand.allCases.allSatisfy { !$0.title.isEmpty })
}

@Test func shippedCommandsAreOnWhenStateAllows() {
    var project = commandProject("keyed", .live)
    project.newComposition()
    project.selectComposition("comp-1")
    project.selectLayer("comp-1-layer-2")
    for command in shippedCommands {
        #expect(project.unavailableHelp(for: command) == nil, "\(command)")
    }
}

@Test func shippedCommandsSayWhatTheyNeed() {
    let none = HaloProject()
    #expect(none.unavailableHelp(for: .newComposition) == nil)
    for command in shippedCommands.dropFirst() {
        #expect(none.unavailableHelp(for: command) == "Create a composition first.", "\(command)")
    }
    let keyed = commandProject("keyed", .live)
    #expect(keyed.unavailableHelp(for: .setInPoint) == "Select a layer first.")
    #expect(keyed.unavailableHelp(for: .setOutPoint) == "Select a layer first.")
    #expect(keyed.unavailableHelp(for: .deleteComposition) == "A project keeps at least one composition.")
    #expect(keyed.unavailableHelp(for: .selectLayer("gone")) == "That layer no longer exists.")
    #expect(keyed.unavailableHelp(for: .selectComposition("gone")) == "The composition no longer exists.")
}

@Test func undoAndRedoTitlesNameTheStep() {
    var project = commandProject("keyed", .fake)
    #expect(project.title(for: .undo) == "Undo")
    #expect(project.title(for: .redo) == "Redo")
    project.newLayer(.solid)
    #expect(project.title(for: .undo) == "Undo New Layer")
    #expect(project.title(for: .newLayer(.text)) == "Text")
    #expect(project.title(for: .openRecent("/tmp/Bounce.halo")) == "Bounce.halo")
}

/// Key editing's contract (KE-1): the four cases sit in the easing area, a
/// pick acts on today's lane pick, Select All Keys and a move wait on KE-3 and KE-4.
@Test func keyEditingCasesAreInTheEasingArea() throws {
    let ball = "comp-1-layer-2"
    let cases: [HaloCommand] = [
        .pickLaneKeys(layerID: ball, frame: 0, mode: .replace), .selectAllKeys, .moveKeys(by: 6, dragStart: 0), .endKeyDrag,
    ]
    #expect(cases.allSatisfy { HaloCommand.allCases.contains($0) && $0.area == .easing })
    #expect(cases.map(\.title) == ["Select Keys", "Select All Keys", "Move Keyframes", "End Key Drag"])
    var project = commandProject("keyed", .fake)
    #expect(project.unavailableHelp(for: .pickLaneKeys(layerID: ball, frame: nil, mode: .toggle)) == nil)
    #expect(project.unavailableHelp(for: .selectAllKeys) == "Not built yet (KE-3).")
    #expect(project.unavailableHelp(for: .moveKeys(by: 6, dragStart: 0)) == "Not built yet (KE-4).")
    #expect(project.selectAllKeysHelp == "Not built yet (KE-3).")
    #expect(project.moveKeysHelp == "Not built yet (KE-4).")
    project.pickLaneKeys(layerID: ball, frame: 0, mode: .replace)
    #expect(project.selectedLayerID == ball)
    #expect(project.pickedFrames(of: ball) == [0])
    project.pickLaneKeys(layerID: ball, frame: 24, mode: .extend)
    #expect(project.pickedFrames(of: ball) == [0, 24])
    #expect(project.pickedFrames(of: "comp-1-layer-1").isEmpty)
    project.pickLaneKeys(layerID: ball, frame: nil, mode: .replace)
    #expect(project.pickedFrames(of: ball).isEmpty)
    #expect(project.history.undo.isEmpty)
}
