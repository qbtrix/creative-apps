// PhotoRetouchOptions.swift: the Paint Bucket's, Spot Heal's and Remove's
// options in the inspector's Tool Options (fill-heal FH-3), under each tool's
// one-line hint (ToolOptionsSection). The bucket: Tolerance, Contiguous and
// All Layers (`PhotoWorkspace.bucketOptions`); the heal tools: the brush's
// Size and Hardness. Every control is identified "photo.tool.<name>". Values
// in, intents out.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoRetouchOptions: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    static let bucketHint = "Click the image to fill the color region under the pointer with the brush color."
    static let spotHealHint = "Click a spot or blemish to heal it from its surroundings."
    static let removeHint = "Paint over an object to remove it; the area fills from around it."

    var body: some View {
        switch model.tool {
        case .bucket: bucket
        case .spotHeal: heal(Self.spotHealHint)
        default: heal(Self.removeHint)
        }
    }

    @ViewBuilder
    private var bucket: some View {
        let options = model.bucketOptions
        hint(Self.bucketHint)
        InspectorSliderRow(
            "Tolerance", value: Double(options.tolerance), in: PhotoWorkspace.bucketToleranceRange, decimals: 0
        ) { perform(.bucketOption(.tolerance(Int($0.rounded())))) }
        .accessibilityIdentifier("photo.tool.tolerance")
        toggle("Contiguous", "photo.tool.contiguous", options.contiguous) { .contiguous($0) }
        toggle("All Layers", "photo.tool.all-layers", options.sampleAllLayers) { .sampleAllLayers($0) }
    }

    @ViewBuilder
    private func heal(_ text: String) -> some View {
        let options = model.toolOptions
        hint(text)
        InspectorSliderRow("Size", value: options.size, in: ToolOptions.sizeRange, unit: "px", decimals: 0) {
            perform(.toolOption(.size($0)))
        }
        .accessibilityIdentifier("photo.tool.size")
        InspectorSliderRow(
            "Hardness", value: options.hardnessPercent, in: ToolOptions.hardnessRange, unit: "%", decimals: 0
        ) { perform(.toolOption(.hardness(percent: $0))) }
        .accessibilityIdentifier("photo.tool.hardness")
    }

    private func toggle(
        _ title: String, _ id: String, _ isOn: Bool, _ edit: @escaping @Sendable (Bool) -> BucketOptionEdit
    ) -> some View {
        InspectorRow("") {
            Toggle(title, isOn: Binding(get: { isOn }, set: { perform(.bucketOption(edit($0))) }))
                .toggleStyle(.checkbox)
        }
        .accessibilityIdentifier(id)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(SuiteFont.inspectorMeta)
            .foregroundStyle(SuiteColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
