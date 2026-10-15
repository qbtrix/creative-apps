// CropOptions.swift: the crop tool's options in the Adjust tab (PV-3): the
// pending crop's X, Y, W and H as ScrubFields two per row in a Grid (X over
// W, Y over H, equal columns), the six aspect chips, Swap, then Apply Crop
// and Cancel. Apply carries no Return shortcut, so Return in a field commits
// the field; Return on the canvas applies through `.confirm`. Cancel carries
// no Escape shortcut either, which would close a field being typed in before
// its own Escape; Escape on the canvas cancels through `.dismiss`.
// Each field reports its bounds through CropFieldBoundsKey as an anchor, so
// a test measures the 2 x 2 grid without an assistive client; nothing in the
// app reads it. Values in, intents out.
import PhotoModel
import SuiteUI
import SwiftUI

struct CropOptions: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    /// The packet's empty-state wording, still asserted by PhotoCropOptionsSnapshots;
    /// the panel now draws `model.cropCaption`. Drop this once that test reads the model.
    static let emptyCaption = "Drag on the image, or type a size"

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            // The one instruction line, always present so nothing moves when a crop appears.
            Text(model.cropCaption)
                .font(SuiteFont.inspectorMeta)
                .foregroundStyle(SuiteColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("photo.crop.caption")
            Grid(horizontalSpacing: SuiteSpacing.xs, verticalSpacing: SuiteSpacing.xs) {
                GridRow {
                    field(.x)
                    field(.y)
                }
                GridRow {
                    field(.width)
                    field(.height)
                }
            }
            // The chips are found by title until ChoiceChips takes per-chip identifiers (#1148).
            ChoiceChips(
                options: CropAspect.presets.map { InspectorOption(id: $0, title: $0.title) },
                selected: Self.preset(for: model.cropAspect)
            ) { perform(.crop(.aspect($0))) }
                .disabled(model.canvas == nil)
                .help(model.canvas == nil ? "Open an image to choose a crop shape." : "")
            InspectorAction(ToolbarAction(
                "Swap", systemImage: "arrow.left.arrow.right", unavailableHelp: model.cropSwapHelp,
                identifier: "photo.crop.swap"
            ) { perform(.crop(.swap)) })
            HStack(spacing: SuiteSpacing.xs) {
                let why = model.cropApplyHelp
                InspectorAction(ToolbarAction(
                    "Apply Crop", systemImage: "crop", unavailableHelp: why, identifier: "photo.crop.apply"
                ) { perform(.applyCrop) })
                InspectorAction(ToolbarAction(
                    "Cancel", systemImage: "xmark", unavailableHelp: why, identifier: "photo.crop.cancel"
                ) { perform(.cancelCrop) })
            }
        }
    }

    /// The chip a lock shows as on: a portrait-swapped ratio (2:3) lights its
    /// landscape preset (3:2).
    static func preset(for aspect: CropAspect) -> CropAspect {
        guard case .ratio(let w, let h) = aspect, !CropAspect.presets.contains(aspect) else { return aspect }
        return .ratio(h, w)
    }

    /// One of X, Y, W, H: whole canvas pixels, X and Y from 0, W and H from 1,
    /// up to the canvas's size. With nothing pending it shows the whole
    /// image's rect (until ScrubField takes a placeholder), and takes typing
    /// once a shape is locked.
    private func field(_ field: CropField) -> some View {
        let enabled = model.cropFieldsEnabled
        let (label, name, id): (String, String, String) =
            switch field {
            case .x: ("X", "X", "photo.crop.x")
            case .y: ("Y", "Y", "photo.crop.y")
            case .width: ("W", "Width", "photo.crop.width")
            case .height: ("H", "Height", "photo.crop.height")
            }
        let side = field == .x || field == .width ? model.canvas?.width : model.canvas?.height
        let low: Double = field == .x || field == .y ? 0 : 1
        let reason = model.cropFieldsUnavailableHelp
        return InspectorRow(label) {
            ScrubField(
                name, value: Double(model.cropFieldDisplay(field)), in: low...max(low, Double(side ?? 1)), step: 1,
                unit: "px", decimals: 0
            ) { number in
                guard number.isFinite else { return }
                perform(.crop(.field(field, Int(number.rounded()))))
            }
            .suiteControl(id: id, enabled: enabled, reason: reason)
            .anchorPreference(key: CropFieldBoundsKey.self, value: .bounds) { [id: $0] }
        }
        .disabled(!enabled)
        .help(reason ?? model.cropFieldHelp(field))
    }
}

/// Each crop field's bounds by accessibility identifier, for the grid test.
struct CropFieldBoundsKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, next in next }
    }
}
