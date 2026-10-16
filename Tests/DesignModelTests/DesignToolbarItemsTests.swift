// DesignToolbarItemsTests.swift: the toolbar's eight commands each act or say
// why (DS-1, shell-parity). A new workspace offers only New and Open; a drawn
// rectangle names Undo and leaves Redo with nothing to do; the identifiers the
// journeys find stay put. Runs on Linux and macOS.
import DesignModel
import Testing

private let closed = "Create or open a file first."

@Test func toolbarOnNewWorkspaceOffersOnlyNewAndOpen() {
    let workspace = DesignWorkspace()
    #expect(DesignToolbarItem.newFile.unavailableHelp(in: workspace) == nil)
    #expect(DesignToolbarItem.open.unavailableHelp(in: workspace) == nil)
    for item in [DesignToolbarItem.save, .zoomOut, .fit, .zoomIn] {
        #expect(item.unavailableHelp(in: workspace) == closed, "\(item)")
    }
    #expect(DesignToolbarItem.undo.unavailableHelp(in: workspace) == "Nothing to undo.")
    #expect(DesignToolbarItem.redo.unavailableHelp(in: workspace) == "Nothing to redo.")
    #expect(DesignToolbarItem.undo.title(in: workspace) == "Undo")
    #expect(DesignToolbarItem.redo.title(in: workspace) == "Redo")
}

@Test func toolbarAfterDrawingARectangleNamesUndo() {
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(40, 40), pt(200, 160))
    #expect(DesignToolbarItem.undo.title(in: workspace) == "Undo Add Rectangle")
    #expect(DesignToolbarItem.undo.unavailableHelp(in: workspace) == nil)
    #expect(DesignToolbarItem.redo.title(in: workspace) == "Redo")
    #expect(DesignToolbarItem.redo.unavailableHelp(in: workspace) == "Nothing to redo.")
    for item in [DesignToolbarItem.newFile, .open, .save, .zoomOut, .fit, .zoomIn] {
        #expect(item.unavailableHelp(in: workspace) == nil, "\(item) is off on an open file")
    }
}

@Test func toolbarAfterUndoNamesRedo() {
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(40, 40), pt(200, 160))
    workspace.undo()
    #expect(DesignToolbarItem.redo.title(in: workspace) == "Redo Add Rectangle")
    #expect(DesignToolbarItem.redo.unavailableHelp(in: workspace) == nil)
}

@Test func toolbarHistoryWaitsWhileEditingText() {
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(40, 40), pt(200, 160))
    workspace.gesture(.text, pt(300, 300), pt(300, 300))
    #expect(workspace.editingTextID != nil)
    #expect(DesignToolbarItem.undo.unavailableHelp(in: workspace) == "Finish editing the text first.")
    #expect(DesignToolbarItem.redo.unavailableHelp(in: workspace) == "Finish editing the text first.")
}

@Test func toolbarDisabledItemsAlwaysSayWhy() {
    var drawn = openDesign()
    drawn.gesture(.rectangle, pt(40, 40), pt(200, 160))
    for workspace in [DesignWorkspace(), openDesign(), drawn] {
        for item in DesignToolbarItem.allCases {
            if let help = item.unavailableHelp(in: workspace) {
                #expect(!help.isEmpty, "\(item) is disabled with empty help")
            }
            #expect(!item.title(in: workspace).isEmpty)
            #expect(!item.systemImage.isEmpty)
        }
    }
}

@Test func toolbarIdentifiersAreUniqueAndKeepTheJourneyOnes() {
    let ids = DesignToolbarItem.allCases.map(\.identifier)
    #expect(ids.count == 8)
    #expect(Set(ids).count == ids.count)
    #expect(ids.allSatisfy { $0.hasPrefix("design.bar.") })
    #expect(DesignToolbarItem.undo.identifier == "design.bar.undo")
    #expect(DesignToolbarItem.redo.identifier == "design.bar.redo")
}

@Test func toolbarKeepsTodaysSymbolsAndTitles() {
    let workspace = DesignWorkspace()
    let expected: [(DesignToolbarItem, String, String)] = [
        (.newFile, "New", "plus"),
        (.open, "Open", "folder"),
        (.save, "Save", "square.and.arrow.down"),
        (.undo, "Undo", "arrow.uturn.backward"),
        (.redo, "Redo", "arrow.uturn.forward"),
        (.zoomOut, "Zoom Out", "minus.magnifyingglass"),
        (.fit, "Fit Page", "arrow.up.left.and.arrow.down.right"),
        (.zoomIn, "Zoom In", "plus.magnifyingglass"),
    ]
    for (item, title, symbol) in expected {
        #expect(item.title(in: workspace) == title)
        #expect(item.systemImage == symbol)
    }
}
