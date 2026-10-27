// PhotoToolOptions.swift: the Tool Options section of the inspector, which
// shows the active tool's options. The brush, eraser, clone and heal preset
// menu (ToolOptions.presets) and sliders
// and the marquee's actions live here; the crop's, selection's, transform's
// and eyedropper's own options each live in their file (CropOptions,
// SelectOptions, TransformOptions, SampleOptions). Values in, intents out.
import PhotoModel
import SuiteUI
import SwiftUI

/// The active tool's options: a preset, size, hardness and opacity for the brush (plus
/// its color) and the eraser, each tool's own; what to do with a selection;
/// applying a crop; the eyedropper's sample size and the brush color it picks into.
struct ToolOptionsSection: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    /// The Eyedropper's one-line hint, like each other tool's.
    static let eyedropperHint = "Click the image to pick a color for the brush."
    /// The Gradient tool's one-line hint.
    static let gradientHint = "Drag across the image to draw a gradient from the press to the release."
    /// The Type tool's one-line hint.
    static let typeHint = "Click the image to type. Return adds the text; Escape cancels it."
    /// The Pen's one-line hint.
    static let penHint = "Click for corners, drag for curves, click the first point to close; Return leaves the path open. Hold Command to move points."

    var body: some View {
        let options = model.toolOptions
        InspectorSection("Tool Options") {
            switch model.tool {
            case .brush, .eraser, .clone, .heal:
                if model.tool == .clone { hint("Option-click to set the source, then paint to clone from it.") }
                if model.tool == .heal {
                    hint("Option-click to set the source, then paint over a blemish to heal it with the source's texture.")
                }
                presetRow(options)
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
            case .marquee, .ellipse, .lasso, .polygon, .wand:
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
                SelectOptions(model: model, perform: perform)
            case .crop:
                // CropOptions draws the crop's one instruction line itself.
                CropOptions(model: model, perform: perform)
            case .move:
                hint(model.moveHint)
                // An adjustment layer can't move: its rows would only sit there disabled.
                if model.canMoveSelection { TransformOptions(model: model, perform: perform) }
            case .eyedropper:
                hint(Self.eyedropperHint)
                SampleOptions(model: model, perform: perform)
                // The brush colour a pick lands in, so the pick shows without switching tools.
                colorRow(options)
            case .gradient:
                hint(Self.gradientHint)
                PhotoFillToolOptions(model: model, perform: perform)
            case .text:
                hint(Self.typeHint)
            case .bucket, .spotHeal, .remove:
                PhotoRetouchOptions(model: model, perform: perform)
            case .pen:
                hint(Self.penHint)
            }
        }
    }

    /// The kernel's brush presets as a menu; it names the one the settings
    /// match, or Custom once any setting differs, and a choice sets them all.
    private func presetRow(_ options: ToolOptions) -> some View {
        let custom = InspectorOption(id: "custom", title: "Custom")
        let presets = ToolOptions.presets.map { InspectorOption(id: $0.id, title: $0.name) }
        return InspectorPickerRow(
            "Preset", options: options.preset == nil ? [custom] + presets : presets,
            selection: options.preset?.id ?? custom.id
        ) { id in
            if let preset = ToolOptions.presets.first(where: { $0.id == id }) { perform(.toolOption(.preset(preset))) }
        }
        .accessibilityIdentifier("photo.tool.preset")
    }

    private func colorRow(_ options: ToolOptions) -> some View {
        InspectorColorWellRow("Color", color: options.hex) { perform(.toolOption(.brushColor($0))) }
        .accessibilityIdentifier("photo.tool.color")
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(SuiteFont.inspectorMeta)
            .foregroundStyle(SuiteColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func command(_ title: String, _ symbol: String, help: String?, _ intent: PhotoIntent) -> some View {
        toolCommand(title, symbol, help: help, intent, perform: perform)
    }
}

/// The outlined inspector action for `intent`, identified as
/// "photo.tool.<title-in-kebab-case>"; disabled, saying why, while `help` is set.
@MainActor
func toolCommand(
    _ title: String, _ symbol: String, help: String?, _ intent: PhotoIntent, perform: @escaping PhotoPerform
) -> some View {
    InspectorAction(ToolbarAction(title, systemImage: symbol, unavailableHelp: help) { perform(intent) })
        .accessibilityIdentifier("photo.tool." + title.lowercased().replacingOccurrences(of: " ", with: "-"))
}

/// Photo's one bridge to SuiteUI's HexColor: the brush color's 8-bit sRGB channels.
extension ToolOptions {
    var hex: HexColor { HexColor(red, green, blue) }
}

extension ToolOptionEdit {
    /// The brush color edit for `hex`.
    static func brushColor(_ hex: HexColor) -> ToolOptionEdit { .color(red: hex.red, green: hex.green, blue: hex.blue) }
}
