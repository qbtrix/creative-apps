// PhotoAdjustmentLayerSnapshots.swift: the Layers tab on the `layered`
// fixture (Paint, Curves 1, Background; AL-6 of photo-adjustment-layers):
// "Curves 1" shows the adjustment symbol (slider.horizontal.3) and the pixel
// layers the photo symbol, every row's eye and kind symbol carry
// `photo.layer.<id>.eye` and `photo.layer.<id>.kind` with labels, and an
// adjustment at the bottom gets the info line "Nothing below to adjust.".
// Writes photo-adjustment-layer-light.png, photo-adjustment-layer-dark.png
// and, with Curves 1 moved to the bottom, photo-adjustment-layer-bottom-light.png
// and photo-adjustment-layer-bottom-dark.png.
// macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoAdjustmentLayerSnapshots {
    @Test func layersTab() throws {
        let model = try PhotoWorkspace.fixture(.layered)
        #expect(model.layers.map(\.name) == ["Paint", "Curves 1", "Background"])
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoPanel(model: model, tab: .layers)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "photo-adjustment-layer-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// Each row's symbol, kind label and identifiers: the adjustment reads
    /// "Adjustment layer" with slider.horizontal.3, pixel layers "Image layer"
    /// with photo; no two rows share an identifier.
    @Test func rowsCarryKindAndIdentifiers() throws {
        let model = try PhotoWorkspace.fixture(.layered)
        let curves = try #require(model.layers.first { $0.name == "Curves 1" })
        let paint = try #require(model.layers.first { $0.name == "Paint" })
        #expect(PhotoLayerRow.kindSymbol(curves.kind) == "slider.horizontal.3")
        #expect(PhotoLayerRow.kindLabel(curves.kind) == "Adjustment layer")
        #expect(PhotoLayerRow.kindSymbol(paint.kind) == "photo")
        #expect(PhotoLayerRow.kindLabel(paint.kind) == "Image layer")
        var identifiers = Set<String>()
        for layer in model.layers {
            #expect(PhotoLayerRow.eyeIdentifier(layer.id) == "photo.layer.\(layer.id).eye")
            #expect(PhotoLayerRow.kindIdentifier(layer.id) == "photo.layer.\(layer.id).kind")
            #expect(!PhotoLayerRow.kindLabel(layer.kind).isEmpty)
            identifiers.insert(PhotoLayerRow.eyeIdentifier(layer.id))
            identifiers.insert(PhotoLayerRow.kindIdentifier(layer.id))
        }
        #expect(identifiers.count == model.layers.count * 2)
        #expect(model.layers.allSatisfy { model.layerInfo($0.id) == nil }, "Curves 1 has layers below it")
    }

    /// An adjustment row at the bottom shows its info line under the name.
    @Test func bottomAdjustmentInfoLine() throws {
        var model = try PhotoWorkspace.fixture(.layered)
        let curves = try #require(model.layers.first { $0.name == "Curves 1" })
        model.moveLayers(fromOffsets: [1], toOffset: 3)
        #expect(model.layers.last?.id == curves.id)
        #expect(model.layerInfo(curves.id) == "Nothing below to adjust.")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoPanel(model: model, tab: .layers)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "photo-adjustment-layer-bottom-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
