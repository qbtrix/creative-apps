// SidebarTests.swift: SidebarItem, SidebarToggle and SidebarSection values.
// macOS only.
import SuiteModel
import SuiteUI
import Testing

@Test func sidebarItemBuiltTheOldWayHasNoTogglesOrChildren() {
    let item = SidebarItem(id: "a", title: "All", systemImage: "photo", count: 3)
    #expect(item.toggles.isEmpty)
    #expect(item.children.isEmpty)
    #expect(item.count == 3)
}

@Test func sidebarToggleShowsItsOnSymbolOnlyWhenOn() {
    let on = SidebarToggle(id: "v", title: "Visible", onSymbol: "eye", offSymbol: "eye.slash", isOn: true)
    let off = SidebarToggle(id: "v", title: "Visible", onSymbol: "eye", offSymbol: "eye.slash", isOn: false)
    #expect(on.systemImage == "eye")
    #expect(off.systemImage == "eye.slash")
}

@Test func sidebarToggleIdentifierNamesItsRowAndKeepsAcrossStates() {
    let on = SidebarToggle(id: "visible", title: "Hide Layer", onSymbol: "eye", offSymbol: "eye.slash", isOn: true)
    let off = SidebarToggle(id: "visible", title: "Show Layer", onSymbol: "eye", offSymbol: "eye.slash", isOn: false)
    #expect(on.identifier(in: "layer-1") == "suite.sidebar.layer-1.visible")
    #expect(off.identifier(in: "layer-1") == on.identifier(in: "layer-1"))
    #expect(on.identifier(in: "layer-2") != on.identifier(in: "layer-1"))
}

@Test func sidebarItemKeepsItsTogglesAndChildrenInOrder() {
    let lock = SidebarToggle(id: "l", title: "Lock", onSymbol: "lock", offSymbol: "lock.open", isOn: false)
    let child = SidebarItem(id: "c", title: "Child", systemImage: "square")
    let item = SidebarItem(id: "p", title: "Group", systemImage: "folder", toggles: [lock], children: [child])
    #expect(item.toggles.map(\.id) == ["l"])
    #expect(item.children.map(\.id) == ["c"])
}

@Test func sidebarSectionDefaultsToNoAddAction() {
    let section = SidebarSection(id: "layers", title: "Layers", items: [])
    #expect(section.addAction == nil)
    let withAdd = SidebarSection(id: "layers", title: "Layers", items: [], addAction: ToolbarAction("New Layer", systemImage: "plus"))
    #expect(withAdd.addAction?.title == "New Layer")
}

@Test func doubleClickOnAToggleNeverStartsARename() {
    #expect(!SidebarRow.doubleClickRenames(.toggle, renamable: true, renaming: false))
    #expect(!SidebarRow.doubleClickRenames(.toggle, renamable: false, renaming: false))
}

@Test func doubleClickOnTheTitleRenamesOnlyARenamableRowNotAlreadyRenaming() {
    #expect(SidebarRow.doubleClickRenames(.title, renamable: true, renaming: false))
    #expect(!SidebarRow.doubleClickRenames(.title, renamable: false, renaming: false))
    #expect(!SidebarRow.doubleClickRenames(.title, renamable: true, renaming: true))
}

@Test func doubleClickOnBlankSpaceBesideTheTogglesNeverStartsARename() {
    #expect(!SidebarRow.doubleClickRenames(.blank, renamable: true, renaming: false))
    #expect(!SidebarRow.doubleClickRenames(.blank, renamable: false, renaming: false))
    #expect(!SidebarRow.doubleClickRenames(.blank, renamable: true, renaming: true))
}

@Test func sidebarItemBuiltTheOldWayIsNotDimmed() {
    let item = SidebarItem(id: "a", title: "All", systemImage: "photo", count: 3)
    #expect(!item.isDimmed)
    #expect(!SidebarItem(id: "l", title: "Flare", app: .flare).isDimmed)
    let look = SidebarRowLook(item)
    #expect(look.title == nil)
    #expect(look.isSelectable)
}

@Test func dimmedRowDrawsItsTitleInTextSecondaryAndStaysSelectable() {
    let eye = SidebarToggle(id: "v", title: "Visible", onSymbol: "eye", offSymbol: "eye.slash", isOn: false)
    let item = SidebarItem(id: "hidden", title: "Hidden Layer", systemImage: "square", toggles: [eye], isDimmed: true)
    let look = SidebarRowLook(item)
    #expect(look.title == SuiteColor.textSecondary)
    #expect(look.isSelectable)
    #expect(item.toggles == [eye])
}

@Test func dimmedDescendantStaysDimmedAtTheSecondLevel() {
    let grandchild = SidebarItem(id: "g", title: "Locked", systemImage: "square", isDimmed: true)
    let child = SidebarItem(id: "c", title: "Group", systemImage: "folder", children: [grandchild])
    let parent = SidebarItem(id: "p", title: "Root", systemImage: "folder", children: [child])
    #expect(parent.secondLevelRows.map(\.isDimmed) == [false, true])
}
