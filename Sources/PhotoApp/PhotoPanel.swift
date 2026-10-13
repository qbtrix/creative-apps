// PhotoPanel.swift: the right panel of a Photo window. Segmented tabs switch
// between Adjust (the image header, the active tool's options, then the
// adjustment sections) and Layers (the layer list with show/hide eyes and
// drag to reorder, New, Delete and Rename, and the selected layer's blend
// mode and opacity). With no image open it says how to start. Values in,
// intents out. Every control here carries a `photo.tool.*` or `photo.layer.*`
// accessibility identifier for the UI journeys and the app audit.
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
            if model.canvas != nil {
                InspectorHeader(model.inspectorHeaderTitle, details: model.inspectorHeaderDetails)
                if tab == .adjust {
                    // No scroller: its page areas are buttons VoiceOver can't name
                    // (the app audit's unnamed check); the panel still scrolls.
                    // No scroller: its page areas are buttons VoiceOver can't name
                    // (the app audit's unnamed check); the panel still scrolls.
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ToolOptionsSection(model: model, perform: perform)
                            AdjustmentsPanel(model: model, perform: perform)
                        }
                    }
                    .scrollIndicators(.never)
                    .scrollIndicators(.never)
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
                .accessibilityIdentifier("photo.tool.size")
                InspectorSliderRow(
                    "Hardness", value: options.hardnessPercent, in: ToolOptions.hardnessRange, unit: "%", decimals: 0
                ) { perform(.toolOption(.hardness(percent: $0))) }
                .accessibilityIdentifier("photo.tool.hardness")
                if model.tool == .brush { colorRow(options) }
                InspectorSliderRow(
                    "Opacity", value: options.opacityPercent, in: ToolOptions.opacityRange, unit: "%", decimals: 0
                ) { perform(.toolOption(.opacity(percent: $0))) }
                .accessibilityIdentifier("photo.tool.opacity")
            case .marquee:
                hint("Drag over the image to select. Delete clears the selection; Fill paints it.")
                colorRow(options)
                HStack(spacing: SuiteSpacing.xs) {
                    command("Select All", "checkmark.rectangle", help: nil, .selectAll)
                    command("Deselect", "rectangle.dashed", help: model.canDeselect ? nil : "Nothing is selected.", .deselect)
                }
                HStack(spacing: SuiteSpacing.xs) {
                    let why = model.canEditSelection ? nil : "Select part of the selected layer first."
                    command("Delete", "trash", help: why, .deleteSelection)
                    command("Fill", "paintbrush.fill", help: why, .fillSelection)
                }
            case .crop:
                hint("Drag over the image to choose the crop, then apply it.")
                HStack(spacing: SuiteSpacing.xs) {
                    let why = model.canApplyCrop ? nil : "Drag over the image to choose a crop first."
                    command("Apply Crop", "crop", help: why, .applyCrop).keyboardShortcut(.defaultAction)
                    command("Cancel", "xmark", help: why, .cancelCrop).keyboardShortcut(.cancelAction)
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
        .accessibilityIdentifier("photo.tool.color")
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(SuiteFont.inspectorMeta)
            .foregroundStyle(SuiteColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The outlined inspector action for `intent`, identified as
    /// "photo.tool.<title-in-kebab-case>"; disabled, saying why, while `help` is set.
    private func command(_ title: String, _ symbol: String, help: String?, _ intent: PhotoIntent) -> some View {
        InspectorAction(ToolbarAction(title, systemImage: symbol, unavailableHelp: help) { perform(intent) })
            .accessibilityIdentifier("photo.tool." + title.lowercased().replacingOccurrences(of: " ", with: "-"))
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
            .accessibilityIdentifier("photo.layer.visibility.\(layer.id)")
            Text(layer.name).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
            if layer.blendMode != .normal || layer.opacity < 1 {
                Text("\(layer.blendMode.title) \(Int(layer.opacityPercent.rounded()))%")
                    .font(SuiteFont.inspectorMeta)
                    // The secondary grey reads 3:1 on the selection highlight; WCAG wants 4.5:1.
                    .foregroundStyle(layer.id == model.selectedLayerID ? Color.primary : SuiteColor.secondaryText)
            }
        }
        .font(SuiteFont.inspectorLabel)
    }
}
