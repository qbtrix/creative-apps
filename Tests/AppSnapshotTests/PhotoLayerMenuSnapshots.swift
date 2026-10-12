// PhotoLayerMenuSnapshots.swift: Photo's Layer menu items with no image open
// (all disabled) beside an image with one hidden layer selected (Delete
// disabled, "Show Layer"), and two layers (all enabled, "Hide Layer"), in
// Light and Dark. The menu bar doesn't render here, so the items are drawn in
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
        #expect(hidden.visibilityCommandTitle == "Show Layer" && !hidden.canDeleteSelectedLayer)
        #expect(two.visibilityCommandTitle == "Hide Layer" && two.canDeleteSelectedLayer)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                MenuStates(models: [PhotoWorkspace(), hidden, two]),
                name: "photo-layer-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct MenuStates: View {
    let models: [PhotoWorkspace]
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(models.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    PhotoLayerMenu(actions: actions(models[index]))
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func actions(_ model: PhotoWorkspace) -> PhotoLayerActions {
        PhotoLayerActions(
            newLayer: model.canAddLayer ? {} : nil,
            deleteLayer: model.canDeleteSelectedLayer ? {} : nil,
            renameLayer: model.canEditSelectedLayer ? {} : nil,
            toggleVisibility: model.canEditSelectedLayer ? {} : nil,
            visibilityTitle: model.visibilityCommandTitle)
    }
}
