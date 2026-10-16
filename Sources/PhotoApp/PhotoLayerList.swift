// PhotoLayerList.swift: Photo's layer list: the stack, top first, each row
// with its show/hide eye, kind symbol (photo for pixels, slider.horizontal.3
// for an adjustment layer) and info line (PhotoLayerRow), drag to reorder, and under it a
// SuiteUI SidebarActionRow of New Layer, Delete Layer and Rename Layer…
// (`photo.layer.new`, `.delete`, `.rename`). Delete is disabled on the last
// layer and says why. Values in, intents out.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI

/// The layer rows, then the row of layer commands.
struct PhotoLayerList: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: Binding(get: { model.selectedLayerID }, set: { if let id = $0 { perform(.selectLayer(id)) } })) {
                ForEach(model.layers) { layer in
                    PhotoLayerRow(
                        layer: layer, isSelected: layer.id == model.selectedLayerID, info: model.layerInfo(layer.id),
                        perform: perform
                    )
                    .tag(layer.id)
                }
                .onMove { perform(.moveLayers($0, $1)) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // The focused selection fills with the tint under white text. Brand blue
            // reads 4.23:1 there; accentFill, the suite's fill for white text, 5.05:1.
            .tint(SuiteColor.accentFill)
            .accessibilityIdentifier("photo.layers")
            SidebarActionRow(Self.commands(model, perform))
                .padding(.horizontal, SuiteSpacing.xs)
        }
    }

    /// New Layer, Delete Layer (disabled on the last layer) and Rename Layer….
    static func commands(_ model: PhotoWorkspace, _ perform: @escaping PhotoPerform) -> [ToolbarAction] {
        [
            ToolbarAction("New Layer", systemImage: "plus", identifier: "photo.layer.new") { perform(.addLayer) },
            ToolbarAction(
                "Delete Layer", systemImage: "trash",
                unavailableHelp: model.canDeleteSelectedLayer ? nil : "The last layer can't be deleted.",
                identifier: "photo.layer.delete"
            ) { perform(.deleteLayer) },
            ToolbarAction("Rename Layer…", systemImage: "pencil", identifier: "photo.layer.rename") { perform(.renameLayer) },
        ]
    }
}

/// One Layers row: the show/hide eye, the kind symbol, the name with the
/// Model's info line under it (`layerInfo`), and the blend mode and opacity
/// when either is not the default. The eye and the kind symbol carry
/// `photo.layer.<id>.eye` and `photo.layer.<id>.kind`, each with a label. Both
/// symbols sit in a fixed `symbolColumn`, so every row's name starts at the
/// same x whatever its kind or visibility (#1633). Hierarchical styles, so on the focused
/// selection's fill the row turns white with the system's own selected text;
/// a selected row draws everything primary, since secondary is too faint there.
struct PhotoLayerRow: View {
    let layer: PhotoLayer
    let isSelected: Bool
    var info: String? = nil
    let perform: PhotoPerform

    static func kindSymbol(_ kind: PhotoLayerKind) -> String {
        if case .adjustment = kind { return "slider.horizontal.3" }
        return "photo"
    }

    static func kindLabel(_ kind: PhotoLayerKind) -> String {
        if case .adjustment = kind { return "Adjustment layer" }
        return "Image layer"
    }

    /// The width of the eye's and the kind symbol's column: eye and
    /// eye.slash, photo and slider.horizontal.3 draw at different widths.
    static let symbolColumn: CGFloat = SuiteSize.iconButtonHit

    static func eyeIdentifier(_ id: PhotoLayer.ID) -> String { "photo.layer.\(id).eye" }
    static func kindIdentifier(_ id: PhotoLayer.ID) -> String { "photo.layer.\(id).kind" }

    var body: some View {
        HStack(spacing: SuiteSpacing.s) {
            Button {
                perform(.toggleVisibility(layer.id))
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .frame(width: Self.symbolColumn)
                    .foregroundStyle(isSelected || layer.isVisible ? HierarchicalShapeStyle.primary : .secondary)
            }
            .buttonStyle(.borderless)
            .help(layer.isVisible ? "Hide Layer" : "Show Layer")
            .accessibilityLabel("\(layer.isVisible ? "Hide" : "Show") \(layer.name)")
            .accessibilityIdentifier(Self.eyeIdentifier(layer.id))
            Image(systemName: Self.kindSymbol(layer.kind))
                .frame(width: Self.symbolColumn)
                .foregroundStyle(isSelected ? HierarchicalShapeStyle.primary : .secondary)
                .help(Self.kindLabel(layer.kind))
                .accessibilityLabel(Self.kindLabel(layer.kind))
                .accessibilityIdentifier(Self.kindIdentifier(layer.id))
            VStack(alignment: .leading, spacing: 0) {
                Text(layer.name).lineLimit(1).truncationMode(.middle)
                if let info {
                    Text(info)
                        .font(SuiteFont.inspectorMeta)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? HierarchicalShapeStyle.primary : .secondary)
                }
            }
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
