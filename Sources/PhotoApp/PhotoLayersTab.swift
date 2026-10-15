// PhotoLayersTab.swift: the Layers tab of a Photo window's right panel: the
// layer list with show/hide eyes and drag to reorder, New, Delete and Rename,
// and the selected layer's blend mode and opacity. Values in, intents out.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI

/// The Layers tab: the stack, top first, then the selected layer's settings.
struct PhotoLayersPanel: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: Binding(get: { model.selectedLayerID }, set: { if let id = $0 { perform(.selectLayer(id)) } })) {
                ForEach(model.layers) { layer in
                    PhotoLayerRow(layer: layer, isSelected: layer.id == model.selectedLayerID, perform: perform).tag(layer.id)
                }
                .onMove { perform(.moveLayers($0, $1)) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // The focused selection fills with the tint under white text. Brand blue
            // reads 4.23:1 there; accentFill, the suite's fill for white text, 5.05:1.
            .tint(SuiteColor.accentFill)
            .accessibilityIdentifier("photo.layers")
            HStack(spacing: 0) {
                EditorBarItem(ToolbarAction("New Layer", systemImage: "plus") { perform(.addLayer) }, showsTitle: false)
                    .accessibilityIdentifier("photo.layer.new")
                EditorBarItem(
                    ToolbarAction(
                        "Delete Layer", systemImage: "trash",
                        unavailableHelp: model.canDeleteSelectedLayer ? nil : "The last layer can't be deleted.") {
                        perform(.deleteLayer)
                    }, showsTitle: false)
                .accessibilityIdentifier("photo.layer.delete")
                EditorBarItem(ToolbarAction("Rename Layer…", systemImage: "pencil") { perform(.renameLayer) }, showsTitle: false)
                    .accessibilityIdentifier("photo.layer.rename")
                Spacer()
            }
            .padding(.horizontal, SuiteSpacing.xs)
            if let layer = model.selectedLayer {
                InspectorSection("Layer") {
                    InspectorPickerRow(
                        "Blend Mode", options: CoreRaster.BlendMode.allCases.map { InspectorOption(id: $0, title: $0.title) },
                        selection: layer.blendMode) { perform(.blendMode(layer.id, $0)) }
                    .accessibilityIdentifier("photo.layer.blend")
                    InspectorSliderRow("Opacity", value: layer.opacityPercent, in: 0...100, unit: "%", decimals: 0) {
                        perform(.opacity(layer.id, $0))
                    } onEnd: {
                        perform(.endAdjust)
                    }
                    .accessibilityIdentifier("photo.layer.opacity")
                }
            }
        }
    }
}

/// One Layers row: the show/hide eye, the name, and the blend mode and opacity
/// when either is not the default. Hierarchical styles, so on the focused
/// selection's fill the row turns white with the system's own selected text;
/// a selected row draws everything primary, since secondary is too faint there.
struct PhotoLayerRow: View {
    let layer: PhotoLayer
    let isSelected: Bool
    let perform: PhotoPerform

    var body: some View {
        HStack(spacing: SuiteSpacing.s) {
            Button {
                perform(.toggleVisibility(layer.id))
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(isSelected || layer.isVisible ? HierarchicalShapeStyle.primary : .secondary)
            }
            .buttonStyle(.borderless)
            .help(layer.isVisible ? "Hide Layer" : "Show Layer")
            .accessibilityLabel("\(layer.isVisible ? "Hide" : "Show") \(layer.name)")
            .accessibilityIdentifier("photo.layer.visibility.\(layer.id)")
            Text(layer.name).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
            if layer.blendMode != .normal || layer.opacity < 1 {
                Text("\(layer.blendMode.title) \(Int(layer.opacityPercent.rounded()))%")
                    .font(SuiteFont.inspectorMeta)
                    // The secondary grey reads 3:1 on the selection highlight; WCAG wants 4.5:1.
                    .foregroundStyle(isSelected ? HierarchicalShapeStyle.primary : .secondary)
            }
        }
        .font(SuiteFont.inspectorLabel)
    }
}
