// InspectorActionTests.swift: the tooltip InspectorAction shows. A full-width
// action shows its ToolbarAction's help; an icon-only one has no title on
// screen, so while it can't run its tooltip names it before the reason. A
// selected action (a toggle that is on) draws differently from an idle one.
// macOS only, like the rest of SuiteUI.
import SuiteUI
import SwiftUI
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

/// A toggle action (Library's Show Original) draws differently while it is on.
@MainActor @Test func selectedActionLooksOn() throws {
    func pixels(_ selected: Bool) throws -> [UInt8] {
        let action = ToolbarAction("Show Original", systemImage: "eye", isSelected: selected)
        let renderer = ImageRenderer(content: InspectorAction(action).frame(width: 160, height: 40))
        renderer.scale = 1
        let image = try #require(renderer.cgImage, "no image")
        let data = try #require(image.dataProvider?.data as Data?)
        return [UInt8](data)
    }
    #expect(try pixels(true) != pixels(false), "Show Original looks the same on and off")
}
