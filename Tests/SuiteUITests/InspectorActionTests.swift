// InspectorActionTests.swift: the tooltip InspectorAction shows. A full-width
// action shows its ToolbarAction's help; an icon-only one has no title on
// screen, so while it can't run its tooltip names it before the reason.
// macOS only, like the rest of SuiteUI.
import SuiteUI
import Testing

@Test func titledActionShowsItsHelp() {
    let off = ToolbarAction("Apply Crop", systemImage: "crop", unavailableHelp: "Drag a crop first.")
    #expect(InspectorAction.help(off, iconOnly: false) == "Drag a crop first.")
}

@Test func iconOnlyActionNamesItselfWhileOff() {
    let on = ToolbarAction("Align Left", systemImage: "align.horizontal.left")
    let off = ToolbarAction(
        "Align Left", systemImage: "align.horizontal.left", unavailableHelp: "The layer is already at the left edge.")
    #expect(InspectorAction.help(on, iconOnly: true) == "Align Left")
    #expect(InspectorAction.help(off, iconOnly: true) == "Align Left: The layer is already at the left edge.")
}
