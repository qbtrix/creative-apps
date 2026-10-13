// PhotoPanel.swift: the right panel of a Photo window. Segmented tabs switch
// between Adjust (the image header, the active tool's options, then the
// adjustment sections) and Layers (the layer list with show/hide eyes and
// drag to reorder, New, Delete and Rename, and the selected layer's blend
// mode and opacity). With no image open it says how to start. Values in,
// intents out.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI

enum PhotoPanelTab: Hashable, Sendable {
    case adjust, layers
}

struct PhotoPanel: View {
    let model: PhotoWorkspace
    let tab: PhotoPanelTab
    var onTab: @MainActor (PhotoPanelTab) -> Void = { _ in }
    var perform: PhotoPerform = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SegmentedTabs(
                "Panel", tabs: [InspectorOption(id: .adjust, title: "Adjust"), InspectorOption(id: .layers, title: "Layers")],
                selection: tab, onChange: onTab)
            if let canvas = model.canvas {
                InspectorHeader(
                    model.documentName ?? "Untitled",
                    details: ["\(canvas.width) × \(canvas.height) px", "sRGB · \(model.layers.count) \(model.layers.count == 1 ? "layer" : "layers")"])
                if tab == .adjust {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ToolOptionsSection(model: model, perform: perform)
                            AdjustmentsInspector(settings: model.adjustments) { perform(.adjust($0)) }
                        }
                    }
                } else {
                    PhotoLayersPanel(model: model, perform: perform)
                }
            } else {
                EmptyStateView(
                    PhotoInspectorContent.noImageTitle, systemImage: PhotoInspectorContent.noImageSymbol,
                    message: PhotoInspectorContent.noImageMessage)
            }
        }
    }
}

/// The active tool's options: size, hardness, color and opacity for the brush
/// and eraser; what to do with a selection; applying a crop.
struct ToolOptionsSection: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        let options = model.toolOptions
        InspectorSection("Tool Options") {
            switch model.tool {
            case .brush, .eraser:
                InspectorSliderRow("Size", value: options.size, in: ToolOptions.sizeRange, unit: "px", decimals: 0) {
                    perform(.toolOption(.size($0)))
                }
                InspectorSliderRow(
                    "Hardness", value: options.hardnessPercent, in: ToolOptions.hardnessRange, unit: "%", decimals: 0
                ) { perform(.toolOption(.hardness(percent: $0))) }
                if model.tool == .brush { colorRow(options) }
                InspectorSliderRow(
                    "Opacity", value: options.opacityPercent, in: ToolOptions.opacityRange, unit: "%", decimals: 0
                ) { perform(.toolOption(.opacity(percent: $0))) }
            case .marquee:
                hint("Drag over the image to select. Delete clears the selection; Fill paints it.")
                colorRow(options)
                InspectorRow("") {
                    HStack(spacing: SuiteSpacing.xs) {
                        command("Select All", help: nil, .selectAll)
                        command("Deselect", help: model.canDeselect ? nil : "Nothing is selected.", .deselect)
                    }
                }
                InspectorRow("") {
                    HStack(spacing: SuiteSpacing.xs) {
                        let why = model.canEditSelection ? nil : "Select part of the selected layer first."
                        command("Delete", help: why, .deleteSelection)
                        command("Fill", help: why, .fillSelection)
                    }
                }
            case .crop:
                hint("Drag over the image to choose the crop, then apply it.")
                InspectorRow("") {
                    HStack(spacing: SuiteSpacing.xs) {
                        let why = model.canApplyCrop ? nil : "Drag over the image to choose a crop first."
                        command("Apply Crop", help: why, .applyCrop, prominent: true).keyboardShortcut(.defaultAction)
                        command("Cancel", help: why, .cancelCrop).keyboardShortcut(.cancelAction)
                    }
                }
            case .move:
                hint("Drag over the image to move the selected layer.")
            }
        }
    }

    private func colorRow(_ options: ToolOptions) -> some View {
        InspectorColorWellRow("Color", color: HexColor(options.red, options.green, options.blue)) {
            perform(.toolOption(.color(red: $0.red, green: $0.green, blue: $0.blue)))
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(SuiteFont.inspectorMeta)
            .foregroundStyle(SuiteColor.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SuiteSpacing.s)
            .padding(.bottom, SuiteSpacing.xs)
    }

    /// A small bordered button for `intent`; disabled, saying why, while
    /// `help` is set.
    @ViewBuilder
    private func command(_ title: String, help: String?, _ intent: PhotoIntent, prominent: Bool = false) -> some View {
        let button = Button(title) { perform(intent) }.disabled(help != nil).help(help ?? title)
        if prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}

/// The Layers tab: the stack, top first, then the selected layer's settings.
struct PhotoLayersPanel: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: Binding(get: { model.selectedLayerID }, set: { if let id = $0 { perform(.selectLayer(id)) } })) {
                ForEach(model.layers) { layer in
                    row(layer).tag(layer.id)
                }
                .onMove { perform(.moveLayers($0, $1)) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("photo.layers")
            HStack(spacing: 0) {
                EditorBarItem(ToolbarAction("New Layer", systemImage: "plus") { perform(.addLayer) }, showsTitle: false)
                EditorBarItem(
                    ToolbarAction(
                        "Delete Layer", systemImage: "trash",
                        unavailableHelp: model.canDeleteSelectedLayer ? nil : "The last layer can't be deleted.") {
                        perform(.deleteLayer)
                    }, showsTitle: false)
                EditorBarItem(ToolbarAction("Rename Layer…", systemImage: "pencil") { perform(.renameLayer) }, showsTitle: false)
                Spacer()
            }
            .padding(.horizontal, SuiteSpacing.xs)
            if let layer = model.selectedLayer {
                InspectorSection("Layer") {
                    InspectorPickerRow(
                        "Blend Mode", options: CoreRaster.BlendMode.allCases.map { InspectorOption(id: $0, title: $0.title) },
                        selection: layer.blendMode) { perform(.blendMode(layer.id, $0)) }
                    InspectorSliderRow("Opacity", value: layer.opacityPercent, in: 0...100, unit: "%", decimals: 0) {
                        perform(.opacity(layer.id, $0))
                    }
                }
            }
        }
    }

    private func row(_ layer: PhotoLayer) -> some View {
        HStack(spacing: SuiteSpacing.s) {
            Button {
                perform(.toggleVisibility(layer.id))
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(layer.isVisible ? Color.primary : SuiteColor.secondaryText)
            }
            .buttonStyle(.borderless)
            .help(layer.isVisible ? "Hide Layer" : "Show Layer")
            .accessibilityLabel("\(layer.isVisible ? "Hide" : "Show") \(layer.name)")
            Text(layer.name).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
            if layer.blendMode != .normal || layer.opacity < 1 {
                Text("\(layer.blendMode.title) \(Int(layer.opacityPercent.rounded()))%")
                    .font(SuiteFont.inspectorMeta)
                    .foregroundStyle(SuiteColor.secondaryText)
            }
        }
        .font(SuiteFont.inspectorLabel)
    }
}
