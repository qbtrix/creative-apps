// PhotoToolOptions.swift: the Tool Options section of the inspector, which
// shows the active tool's options. The brush, eraser, clone and heal sliders
// and the marquee's actions live here; the crop's, selection's, transform's
// and eyedropper's own options each live in their file (CropOptions,
// SelectOptions, TransformOptions, SampleOptions). Values in, intents out.
import PhotoModel
import SuiteUI
import SwiftUI

/// The active tool's options: size, hardness and opacity for the brush (plus
/// its color) and the eraser, each tool's own; what to do with a selection;
/// applying a crop.
struct ToolOptionsSection: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    /// The Eyedropper's one-line hint, like each other tool's.
    static let eyedropperHint = "Click the image to pick a color for the brush."

    var body: some View {
        let options = model.toolOptions
        InspectorSection("Tool Options") {
            switch model.tool {
            case .brush, .eraser, .clone, .heal:
                if model.tool == .clone { hint("Option-click to set the source, then paint to clone from it.") }
                if model.tool == .heal {
                    hint("Option-click to set the source, then paint over a blemish to heal it with the source's texture.")
                }
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
                SelectOptions(model: model, perform: perform)
            case .crop:
                // CropOptions draws the crop's one instruction line itself.
                CropOptions(model: model, perform: perform)
            case .move:
                hint(model.moveHint)
                TransformOptions(model: model, perform: perform)
            case .eyedropper:
                hint(Self.eyedropperHint)
                SampleOptions(model: model, perform: perform)
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
