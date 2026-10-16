// PhotoAdjustmentLayerSnapshots.swift: the sidebar's layer list on the `layered`
// fixture (Paint, Curves 1, Background; AL-6 of photo-adjustment-layers):
// "Curves 1" shows the adjustment symbol (slider.horizontal.3) and the pixel
// layers the photo symbol, every row's eye and kind symbol carry
// `photo.layer.<id>.eye` and `photo.layer.<id>.kind` with labels, and an
// adjustment at the bottom gets the info line "Nothing below to adjust.".
// Writes photo-adjustment-layer-light.png, photo-adjustment-layer-dark.png
// and, with Curves 1 moved to the bottom, photo-adjustment-layer-bottom-light.png
// and photo-adjustment-layer-bottom-dark.png. The panel with its padding fits
// the 900 pt canvas (#1634), and every row's name starts at the same x
// whatever its kind or visibility (#1633).
// macOS only.
import AppKit
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoAdjustmentLayerSnapshots {
    /// The canvas `snapshot` and `render` draw at.
    static let canvas = CGSize(width: 1440, height: 900)

    /// The layer list on the panel fill, inset by SuiteSpacing.xxl, sized so
    /// list and padding fit the canvas's height.
    static func panel(_ model: PhotoWorkspace) -> some View {
        PhotoLayerList(model: model, perform: { _ in })
            .frame(
                width: SuiteSize.inspectorWidth.ideal, height: canvas.height - 2 * SuiteSpacing.xxl,
                alignment: .topLeading
            )
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
    }

    /// The `layered` fixture with Curves 1 moved to the bottom.
    static func bottomCurves() throws -> PhotoWorkspace {
        var model = try PhotoWorkspace.fixture(.layered)
        model.moveLayers(fromOffsets: [1], toOffset: 3)
        return model
    }

    @Test func layersTab() throws {
        let model = try PhotoWorkspace.fixture(.layered)
        #expect(model.layers.map(\.name) == ["Paint", "Curves 1", "Background"])
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                Self.panel(model),
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
        let model = try Self.bottomCurves()
        let curves = try #require(model.layers.first { $0.name == "Curves 1" })
        #expect(model.layers.last?.id == curves.id)
        #expect(model.layerInfo(curves.id) == "Nothing below to adjust.")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                Self.panel(model),
                name: "photo-adjustment-layer-bottom-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// #1634: the panel with its padding fits the canvas, so the top and
    /// bottom pixel rows through the panel's column are the window backdrop,
    /// not panel fill.
    @Test func panelFitsCanvas() throws {
        for model in [try PhotoWorkspace.fixture(.layered), try Self.bottomCurves()] {
            let fitting = NSHostingView(rootView: Self.panel(model)).fittingSize
            #expect(fitting.width <= Self.canvas.width && fitting.height <= Self.canvas.height, "panel is \(fitting)")
            for scheme in [ColorScheme.light, .dark] {
                let image = try #require(render(Self.panel(model), scheme: scheme))
                let backdrop = try #require(image.colorAt(x: 0, y: 0))
                let x = Int(Self.canvas.width / 2)
                for y in [0, Int(Self.canvas.height) - 1] {
                    let pixel = try #require(image.colorAt(x: x, y: y))
                    #expect(pixel == backdrop, "row \(y) at x \(x) is \(pixel), not the backdrop \(backdrop)")
                }
            }
        }
    }

    /// #1633: a row's width less its name's width is the same for an image
    /// layer and an adjustment layer, shown or hidden, so every name starts at
    /// the same x. Measured with no info line and the default blend and
    /// opacity, so the name is the row's only text.
    @Test func namesShareALeadingEdge() throws {
        var model = try PhotoWorkspace.fixture(.layered)
        let background = try #require(model.layers.first { $0.name == "Background" })
        model.toggleVisibility(background.id)
        let paintLayer = try #require(model.layers.first { $0.name == "Paint" })
        model.setBlendMode(paintLayer.id, .normal)
        model.setOpacity(paintLayer.id, percent: 100)
        var leads: [String: CGFloat] = [:]
        for layer in model.layers {
            #expect(model.layerInfo(layer.id) == nil && layer.blendMode == .normal && layer.opacity >= 1)
            let row = PhotoLayerRow(layer: layer, isSelected: false, perform: { _ in }).fixedSize()
            let name = Text(layer.name).font(SuiteFont.inspectorLabel).lineLimit(1).fixedSize()
            leads[layer.name] = NSHostingView(rootView: row).fittingSize.width - NSHostingView(rootView: name).fittingSize.width
        }
        let paint = try #require(leads["Paint"])
        for (name, lead) in leads {
            #expect(abs(lead - paint) <= 0.5, "\(name)'s name starts \(lead - paint) pt off Paint's: \(leads)")
        }
    }
}
