// PhotoLayerMenuSnapshots.swift: Photo's Layer menu items with no image open
// (all disabled) beside an image with one hidden layer selected (Delete and
// the order and selection moves disabled, "Show Layer"), and two layers with
// the top one selected (all but Bring Forward and Select Layer Above), in
// Light and Dark. New Adjustment Layer holds the four kinds (never Blur),
// disabled with "Open an image first." with no image and enabled with one;
// the menu bar doesn't render here, so the items are drawn in
// columns. Writes photo-layer-menu-light.png and photo-layer-menu-dark.png.
// macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoLayerMenuSnapshots {
    @Test func layerMenuStates() throws {
        var hidden = PhotoWorkspace()
        try hidden.newCanvas(width: 1920, height: 1080)
        let background = try #require(hidden.selectedLayerID)
        hidden.toggleVisibility(background)
        var two = hidden
        two.addLayer()
        let menus = [PhotoWorkspace(), hidden, two].map { PhotoMenu(model: $0, perform: { _ in }) }
        #expect(menus[1].visibilityTitle == "Show Layer" && !menus[1].canDeleteLayer && menus[1].canUndo)
        #expect(menus[2].visibilityTitle == "Hide Layer" && menus[2].canDeleteLayer)
        #expect(menus[2].undoTitle == "Undo New Layer" && !menus[0].hasImage)
        for menu in menus {
            #expect(menu.adjustmentLayerKinds == [.exposure, .levels, .curves, .hueSaturation])
        }
        #expect(menus[0].addAdjustmentLayerHelp == "Open an image first.")
        #expect(menus[1].addAdjustmentLayerHelp == nil && menus[2].addAdjustmentLayerHelp == nil)
        #expect(PhotoMenu().addAdjustmentLayerHelp == "Open an image first.")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                MenuStates(menus: menus), name: "photo-layer-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct MenuStates: View {
    let menus: [PhotoMenu]
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(menus.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    PhotoLayerMenu(menu: menus[index])
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
