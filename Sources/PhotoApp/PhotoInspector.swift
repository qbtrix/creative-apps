// PhotoInspector.swift: Photo's inspector pane. Shows the selected layer and
// the image adjustments, or an empty state from PhotoWorkspace.inspectorContent:
// "No Image" with no image open, "No Selection" with no layer selected.
// Reads the model and calls back; never changes it.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoInspector: View {
    let model: PhotoWorkspace
    var onBlendMode: @MainActor (PhotoLayer.ID, CoreRaster.BlendMode) -> Void = { _, _ in }
    var onOpacity: @MainActor (PhotoLayer.ID, Double) -> Void = { _, _ in }
    var onAdjust: @MainActor (AdjustmentEdit) -> Void = { _ in }

    var body: some View {
        switch model.inspectorContent {
        case .noImage:
            EmptyStateView("No Image", systemImage: "photo", message: "Open or create an image to adjust it.")
        case .noSelection:
            EmptyStateView("No Selection", systemImage: "photo", message: "Select a layer to adjust it.")
        case .layer(let layer, let width, let height):
            ScrollView {
                VStack(alignment: .leading, spacing: SuiteSpacing.l) {
                    PhotoLayerInspector(
                        layer: layer, canvasSize: "\(width) × \(height) px",
                        onBlendMode: { onBlendMode(layer.id, $0) },
                        onOpacity: { onOpacity(layer.id, $0) })
                    AdjustmentsInspector(settings: model.adjustments, onEdit: onAdjust)
                }
            }
        }
    }
}
