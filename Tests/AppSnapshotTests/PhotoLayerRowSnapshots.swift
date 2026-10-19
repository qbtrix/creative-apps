// PhotoLayerRowSnapshots.swift: the whole layer list with its command row
// (PhotoLayerList, on LayerTreeList since AL-p3, which draws the selection).
// Writes photo-layer-list-light.png and photo-layer-list-dark.png.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoLayerRowSnapshots {
    /// Background hidden, then Layer 1 at Multiply 50%, selected.
    private func twoLayers() throws -> PhotoWorkspace {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 64, height: 64)
        let background = try #require(model.selectedLayerID)
        model.toggleVisibility(background)
        model.addLayer()
        let top = try #require(model.selectedLayerID)
        model.setBlendMode(top, .multiply)
        model.setOpacity(top, percent: 50)
        return model
    }

    /// The list of both layers with New, Delete and Rename under it.
    @Test func layerList() throws {
        let model = try twoLayers()
        let identifiers = PhotoLayerList.commands(model, { _ in }).map(\.identifier)
        #expect(identifiers == ["photo.layer.new", "photo.layer.delete", "photo.layer.rename"])
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoLayerList(model: model, perform: { _ in })
                    .frame(width: SuiteSize.editorPanelWidth, height: 200)
                    .background(SuiteColor.panel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(SuiteSpacing.xxl),
                name: "photo-layer-list-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
