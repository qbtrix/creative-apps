// DesignWindowOptionsTests.swift: the window's launch arguments (-DesignServices,
// -DesignFixture, -DesignWindowSize), opening a named fixture as an unsaved file,
// the status line's selection count and the control id list. Runs on Linux and macOS.
import Foundation
import Testing

@testable import DesignModel

@Suite struct DesignWindowOptionsTests {
    @Test func servicesAreFakeOnlyWhenAsked() {
        #expect(DesignWindowOptions(arguments: ["app", "-DesignServices", "fake"]).services == .fake)
        #expect(DesignWindowOptions(arguments: ["app"]).services == .live)
        #expect(DesignWindowOptions(arguments: ["app", "-DesignServices", "live"]).services == .live)
        #expect(DesignWindowOptions(arguments: ["app", "-DesignServices", "x"]).services == .live)
        #expect(DesignWindowOptions(arguments: ["app", "-DesignServices"]).services == .live)
    }

    @Test func fixtureNamesTheValue() {
        #expect(DesignWindowOptions(arguments: ["app", "-DesignFixture", "cards"]).fixture == "cards")
        #expect(DesignWindowOptions(arguments: ["app"]).fixture == nil)
        #expect(DesignWindowOptions(arguments: ["app", "-DesignFixture"]).fixture == nil)
    }

    @Test func windowSizeParsesWidthByHeight() {
        let options = DesignWindowOptions(arguments: ["app", "-DesignWindowSize", "880x560", "-DesignFixture", "cards"])
        #expect(options.windowWidth == 880 && options.windowHeight == 560)
        #expect(options.fixture == "cards")
        for bad in ["880", "0x0", "axb", "880x0", "-5x10", "880x560x2", "x560", "infx560"] {
            let parsed = DesignWindowOptions(arguments: ["app", "-DesignWindowSize", bad])
            #expect(parsed.windowWidth == nil && parsed.windowHeight == nil, "\(bad)")
        }
        let missing = DesignWindowOptions(arguments: ["app", "-DesignWindowSize"])
        #expect(missing.windowWidth == nil && missing.windowHeight == nil)
    }

    @Test func openFixtureIsAnUnsavedFileWithNothingToUndo() {
        var workspace = openDesign()
        workspace.useServices(.fake)
        workspace.gesture(.rectangle, pt(10, 10), pt(60, 60))
        #expect(workspace.canUndo)
        let opened = workspace.openFixture("cards")
        #expect(opened)
        #expect(workspace.documentURL == nil && !workspace.canUndo)
        #expect(workspace.pages == DesignFixtures.cards.pages)
        #expect(workspace.services == .fake)
    }

    @Test func openFixtureDropsTheFileLocation() throws {
        var workspace = DesignFixtures.cards
        let data = try workspace.fileData()
        let url = try #require(URL(string: "file:///tmp/a.design"))
        try workspace.open(data, at: url)
        #expect(workspace.documentURL == url)
        let opened = workspace.openFixture("two-pages")
        #expect(opened)
        #expect(workspace.documentURL == nil && workspace.pages.count == 2)
    }

    @Test func unknownFixtureChangesNothing() {
        var workspace = openDesign()
        workspace.gesture(.rectangle, pt(10, 10), pt(60, 60))
        let before = workspace
        let opened = workspace.openFixture("nope")
        #expect(!opened)
        #expect(workspace == before)
    }

    @Test func selectionCountText() {
        var workspace = DesignFixtures.cards
        #expect(workspace.selectionCountText == nil)
        workspace.selectItem("node-2")
        #expect(workspace.selectionCountText == "1 Layer")
        workspace.toggleSelection("node-3")
        #expect(workspace.selectionCountText == "2 Layers")
    }

    @Test func controlIDsAreUniqueAndCoverTheContract() {
        let all = DesignControlID.all
        #expect(Set(all).count == all.count)
        for id in [
            "design.canvas.hover", "design.canvas.badge", "design.inspector.page-width",
            "design.inspector.page-height", "design.canvas.guides", "design.status.selection",
            "design.canvas.selection", "design.status.tool", "design.status.save",
        ] {
            #expect(all.contains(id), "\(id)")
        }
        #expect(all.allSatisfy { $0.hasPrefix("design.") })
        #expect(DesignControlID.tool(.rectangle) == "design.tool.rectangle")
    }
}
