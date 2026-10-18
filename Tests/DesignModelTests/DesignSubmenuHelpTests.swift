// DesignSubmenuHelpTests.swift: the reason Object > Arrange and Object > Align
// are off as a whole (#2465). With nothing selected both ask for a layer;
// with a layer that can move one way the submenu is on; on `.live` Arrange
// is off with its not-built reason. Runs on Linux and macOS.
@testable import DesignModel
import Testing

/// `cards` on `services` with `ids` selected (the first replaces the selection, the rest are added).
private func cards(_ services: DesignServices, _ ids: [String]) -> DesignWorkspace {
    var workspace = DesignFixtures.cards
    workspace.useServices(services)
    if let first = ids.first { workspace.selectItem(first) }
    for id in ids.dropFirst() { workspace.toggleSelection(id) }
    return workspace
}

@Suite struct DesignSubmenuHelpTests {
    @Test func bothSubmenusAreOffWithNothingSelected() {
        for services in [DesignServices.fake, .live] {
            let workspace = cards(services, [])
            #expect(workspace.arrangeMenuHelp == DesignRefusal.nothingSelected.help, "\(services.name)")
            #expect(workspace.alignMenuHelp == "Select a layer to align it.", "\(services.name)")
        }
    }

    @Test func aMovableLayerTurnsArrangeOn() {
        // B sits between A and C, so every fake arrange step can run.
        #expect(cards(.fake, ["node-3"]).arrangeMenuHelp == nil)
    }

    @Test func liveArrangeIsOffWithItsNotBuiltReason() {
        let help = cards(.live, ["node-3"]).arrangeMenuHelp
        #expect(help == NotBuilt("Reordering layers").help)
    }

    @Test func aLayerThatCanAlignTurnsAlignOn() {
        // A is not centred on Desktop, so at least one edge can run.
        #expect(cards(.live, ["node-2"]).alignMenuHelp == nil)
    }

    @Test func submenuHelpIsTheFirstReasonOnlyWhenEveryItemIsOff() {
        #expect(DesignWorkspace.submenuHelp(["first", "second"]) == "first")
        #expect(DesignWorkspace.submenuHelp(["first", nil]) == nil)
        #expect(DesignWorkspace.submenuHelp([nil, "second"]) == nil)
        #expect(DesignWorkspace.submenuHelp([]) == nil)
    }
}
