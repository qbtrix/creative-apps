// HaloMenuStateTests.swift (adopt-command-catalog AC-h3): Halo's menu items read their catalog specs over
// HaloMenuState and stay as today's menus were: on and off as `unavailableHelp(for:)` says with a window, all off
// with "Open a Halo window first." without one, titled by `title(for:)`; a run goes through the catalog.
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloMenuStateTests {
    /// Every command a Halo menu shows, as the menus send it.
    static let menuCommands: [HaloCommand] =
        HaloLayerKind.allCases.map(HaloCommand.newLayer)
        + [.duplicateLayer, .beginRenameLayer, .deleteLayer, .bringLayerForward, .sendLayerBackward,
           .newComposition, .duplicateComposition, .deleteComposition, .undo, .redo,
           .open, .save, .saveAs, .openRenderSheet, .renderFrame,
           .playPause, .toggleLoop, .nextFrame, .previousFrame, .goToStart, .goToEnd, .setInPoint, .setOutPoint]
        + HaloEasingPreset.allCases.map(HaloCommand.setEasing)

    static let states: [HaloProject?] = [nil] + HaloCommandCatalogTests.keyedStates()

    @Test func enabledMatchesTodaysMenus() {
        for (n, project) in Self.states.enumerated() {
            let state = HaloMenuState(project: project)
            for command in Self.menuCommands {
                let today = project.map { $0.unavailableHelp(for: command) } ?? "Open a Halo window first."
                let spec = HaloMenuState.spec(command.commandID)
                #expect(spec.id == command.commandID)
                #expect(spec.availability(state).why == today, "\(command.commandID) on state \(n)")
            }
        }
    }

    @Test func titlesStayTodays() {
        var project = HaloCommandCatalogTests.ballSelected()
        project.newLayer(.solid)
        let state = HaloMenuState(project: project)
        #expect(state.title(.undo) == "Undo New Layer" && state.title(.redo) == "Redo")
        #expect(state.title(.newLayer(.text)) == "Text" && state.title(.setEasing(.easeIn)) == HaloEasingPreset.easeIn.title)
        #expect(HaloMenuState(project: nil).title(.undo) == "Undo")
        #expect(HaloMenuState.spec("file.save").title == "Save")
    }

    @Test func noRecentsSaysWhy() {
        let state = HaloMenuState(project: HaloCommandCatalogTests.ballSelected())
        #expect(HaloMenuState.spec("file.clear-recent").availability(state).why == "No Recent Files")
    }

    @Test func runGoesThroughTheCatalog() throws {
        let catalog = try CommandCatalog<HaloMenuState>(app: "halo", [HaloMenuState.spec("layer.delete")],
                                                        history: { HaloCatalogSteps(project: $0.project ?? HaloProject(services: .fake)) })
        var state = HaloMenuState(project: HaloCommandCatalogTests.ballSelected())
        #expect(try catalog.run("layer.delete", params: .object([:]), on: &state).undoStep == "Delete Layer")
        #expect(state.project?.selectedComposition?.layers.map(\.id) == ["comp-1-layer-1"])
        var none = HaloMenuState(project: nil)
        #expect(throws: CatalogError.self) { try catalog.run("layer.delete", params: .object([:]), on: &none) }
    }

    @Test func placeReadsPlaceImage() {
        let spec = HaloMenuState.spec("place.image")
        #expect(spec.id == "place.image" && spec.title == "Place Image")
        #expect(spec.availability(HaloMenuState(project: nil)).why == "Open a Halo window first.")
        #expect(spec.availability(HaloMenuState(project: HaloProject(services: .fake))).why == HaloProject.noPlaceComposition)
        #expect(spec.availability(HaloMenuState(project: HaloCommandCatalogTests.ballSelected())).why == nil)
    }

    @Test func unknownIDIsNeverAvailable() {
        let spec = HaloMenuState.spec("halo.nothing")
        #expect(spec.availability(HaloMenuState(project: HaloCommandCatalogTests.ballSelected())).why != nil)
    }
}
