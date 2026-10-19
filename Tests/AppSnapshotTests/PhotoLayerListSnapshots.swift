// PhotoLayerListSnapshots.swift: Photo's Layers panel on SuiteUI's
// LayerTreeList (AL-p3), `layered` with Background hidden: the journeys' ids,
// each row's kind symbol (no thumbnail, so names share a leading edge, #1633)
// and caption, with no disclosure column (the layers never nest). Writes
// photo-layer-list-kernel-light/-dark.png. macOS only.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoLayerListSnapshots {
    private func layered() throws -> PhotoWorkspace {
        var model = try PhotoWorkspace.fixture(.layered)
        let background = try #require(model.layers.first { $0.name == "Background" })
        model.toggleVisibility(background.id)
        return model
    }

    @Test func idsAndRowContent() throws {
        let model = try layered()
        let naming = PhotoLayerRow.naming
        #expect(naming.container == "photo.layers")
        #expect(model.layerRows.map(\.name) == ["Paint", "Curves 1", "Background"])
        let decorations = PhotoLayerList.decorations(model)
        for row in model.layerRows {
            #expect(naming.identifier(of: naming.visibility(row), in: row.id) == "photo.layer.\(row.id).eye")
            #expect(naming.visibility(row).title == (row.isHidden ? "Show \(row.name)" : "Hide \(row.name)"))
            let decoration = try #require(decorations[row.id])
            #expect(decoration.symbolID == "photo.layer.\(row.id).kind" && decoration.thumbnail == nil)
            #expect(decoration.caption == model.layerCaption(row.id))
        }
        let curves = try #require(model.layers.first { $0.name == "Curves 1" })
        #expect(decorations[curves.id]?.symbolLabel == "Curves adjustment layer")
        #expect(PhotoLayerRow.options.showsEye && !PhotoLayerRow.options.showsLock)
        // Photo's layers never nest, so the list leaves out the empty disclosure column.
        #expect(!PhotoLayerRow.options.nests)
        let paint = try #require(model.layers.first { $0.name == "Paint" })
        #expect(decorations[paint.id]?.caption == "Multiply 60%")
        #expect(decorations[paint.id]?.help == "Blend mode Multiply, opacity 60%")
    }

    @Test func panel() throws {
        let model = try layered()
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoLayerList(model: model, perform: { _ in })
                    .frame(width: SuiteSize.editorPanelWidth, height: 240)
                    .background(SuiteColor.panel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(SuiteSpacing.xxl),
                name: "photo-layer-list-kernel-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
