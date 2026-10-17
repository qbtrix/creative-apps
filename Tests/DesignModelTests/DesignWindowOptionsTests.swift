// DesignWindowOptionsTests.swift: the three launch arguments parse as the blueprint
// says (a missing value, a malformed size and an unknown service name change nothing),
// openFixture opens an unsaved fixture and keeps the services, and the status line's
// layer count and Zoom to Selection's rect and reason follow the selection. Runs on Linux and macOS.
import DesignModel
import Testing

@Suite struct DesignWindowOptionsTests {
    @Test func noArgumentsGiveTheLiveDefaults() {
        let options = DesignWindowOptions(arguments: ["Design"])
        #expect(options.services.name == "live")
        #expect(options.fixture == nil)
        #expect(options.windowWidth == nil && options.windowHeight == nil)
    }

    @Test func parsesEachLaunchArgument() {
        let options = DesignWindowOptions(arguments: [
            "Design", "-DesignServices", "fake", "-DesignFixture", "cards", "-DesignWindowSize", "880x560",
        ])
        #expect(options.services.name == "fake")
        #expect(options.fixture == "cards")
        #expect(options.windowWidth == 880 && options.windowHeight == 560)
    }

    @Test func anotherServiceNameIsLive() {
        #expect(DesignWindowOptions(arguments: ["-DesignServices", "other"]).services.name == "live")
    }

    @Test func aFlagWithoutAValueIsIgnored() {
        let options = DesignWindowOptions(arguments: ["Design", "-DesignFixture"])
        #expect(options.fixture == nil)
        let sized = DesignWindowOptions(arguments: ["-DesignWindowSize"])
        #expect(sized.windowWidth == nil && sized.windowHeight == nil)
    }

    @Test func malformedWindowSizesAreNil() {
        for size in ["880", "880x", "x560", "0x560", "880x0", "-5x560", "abcxdef", "infx560", "nanx560", "880x560x2"] {
            let options = DesignWindowOptions(arguments: ["-DesignWindowSize", size])
            #expect(options.windowWidth == nil && options.windowHeight == nil, "\(size)")
        }
    }

    @Test func openFixtureOpensAnUnsavedFileAndKeepsTheServices() {
        var workspace = DesignWorkspace()
        workspace.useServices(.fake)
        #expect(workspace.openFixture("cards"))
        #expect(workspace.isOpen && workspace.documentURL == nil && !workspace.canUndo)
        #expect(workspace.pages == DesignFixtures.cards.pages)
        #expect(workspace.services.name == "fake")
    }

    @Test func unknownFixtureChangesNothing() {
        var workspace = DesignWorkspace()
        workspace.newFile()
        let before = workspace
        #expect(!workspace.openFixture("nope"))
        #expect(workspace == before)
    }

    @Test func selectionCountReadsOneThenSeveralThenNothing() {
        var workspace = DesignFixtures.cards
        #expect(workspace.selectionCountText == nil)
        workspace.selectItem("node-2")
        #expect(workspace.selectionCountText == "1 Layer")
        workspace.toggleSelection("node-3")
        #expect(workspace.selectionCountText == "2 Layers")
        workspace.deselect()
        #expect(workspace.selectionCountText == nil)
    }

    @Test func zoomToSelectionFitsTheSelectionBoxOrSaysWhy() {
        var workspace = DesignFixtures.cards
        #expect(workspace.zoomToSelectionRect == nil)
        #expect(workspace.zoomToSelectionHelp == "Select a layer first.")
        workspace.selectItem("node-2")
        #expect(workspace.zoomToSelectionRect == DesignRect(x: 100, y: 100, width: 100, height: 80))
        #expect(workspace.zoomToSelectionHelp == nil)
    }

    @Test func controlIDsAreUniqueAndIncludeTheCanvasSelection() {
        #expect(Set(DesignControlID.all).count == DesignControlID.all.count)
        #expect(DesignControlID.all.contains(DesignControlID.canvasSelection))
        #expect(DesignControlID.barUndo == "design.bar.undo" && DesignControlID.barRedo == "design.bar.redo")
    }
}
