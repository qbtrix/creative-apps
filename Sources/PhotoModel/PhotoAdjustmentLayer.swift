// PhotoAdjustmentLayer.swift: adjustment layers (PV-6, #580). New Adjustment
// Layer adds a layer that holds one kind of adjustment (Exposure, Levels,
// Curves or Hue/Saturation, as `services.adjustmentLayers` offers them) and
// changes the layers under it. Its settings have only that kind enabled, so the
// kind is read from them; the row's eye turns the layer off. Names count per
// kind ("Curves 1", "Curves 2"). The inspector edits `adjustTarget`: the
// selected adjustment layer's own section under its name, or the whole-image
// sections under "Image". An edit to a layer is clamped and refused exactly as
// the whole-image one (AdjustmentSettings), damages the whole canvas at once,
// and one gesture is one undo step (`endAdjustLayer`). A row's kind label
// names the adjustment whatever the layer is called (`PhotoLayerKind.label`,
// #1710), and its blend summary's tooltip says which value is the blend mode
// and which the opacity (`layerBlendSummary`, #1709). Linux-safe.
import CoreRaster

/// A Layers row's trailing summary, "Multiply 60%", and its tooltip and
/// accessibility label, "Blend mode Multiply, opacity 60%" (#1709).
public struct PhotoBlendSummary: Hashable, Sendable {
    public let text: String
    public let help: String
}

extension PhotoLayerKind {
    /// The kind symbol's tooltip and label: "Image layer", or the adjustment
    /// the layer holds, "Curves adjustment layer", read from its settings so
    /// a renamed layer still says what it does (#1710).
    public var label: String {
        guard case .adjustment(let settings) = self else { return "Image layer" }
        let kinds = AdjustmentKind.allCases.filter { settings.isEnabled($0) }.map(\.title)
        return kinds.isEmpty ? "Adjustment layer" : "\(kinds.joined(separator: ", ")) adjustment layer"
    }
}

/// Where the inspector's adjustment edits go (PV-6).
public enum AdjustTarget: Hashable, Sendable {
    case image
    case layer(PhotoLayer.ID, AdjustmentSettings)
}

extension PhotoWorkspace {
    /// The kinds New Adjustment Layer offers: services.adjustmentLayers.kinds.
    public var adjustmentLayerKinds: [AdjustmentKind] { services.adjustmentLayers.kinds }

    /// Why New Adjustment Layer is disabled, as its tooltip; nil when it works.
    public var addAdjustmentLayerHelp: String? {
        canvas == nil ? "Open an image first." : services.adjustmentLayers.unavailableHelp
    }

    /// Adds an adjustment layer of `kind` named "<Kind> <n>" (the lowest n no
    /// layer uses) above the selected layer, and selects it: one "New
    /// Adjustment Layer" step. Ignored while disabled or for a kind not offered.
    public mutating func addAdjustmentLayer(_ kind: AdjustmentKind) {
        guard addAdjustmentLayerHelp == nil, adjustmentLayerKinds.contains(kind) else { return }
        var settings = AdjustmentSettings()
        for other in AdjustmentKind.allCases where other != kind { settings.apply(.setEnabled(other, false)) }
        var number = 1
        while layers.contains(where: { $0.name == "\(kind.title) \(number)" }) { number += 1 }
        record(.stack(stackState), named: "New Adjustment Layer")
        let above = selectedLayerID.flatMap(index(of:)) ?? 0
        selectedLayerID = insertLayer(
            named: "\(kind.title) \(number)", pixels: nil, kind: .adjustment(settings), at: above)
        touch(.all)
    }

    /// The selected adjustment layer and its settings, or the whole image.
    public var adjustTarget: AdjustTarget {
        guard let layer = selectedLayer, case .adjustment(let settings) = layer.kind else { return .image }
        return .layer(layer.id, settings)
    }

    /// Changes one value of adjustment layer `id`, clamped and refused as
    /// AdjustmentSettings does. An edit to a section the layer doesn't hold,
    /// or to its enable switch (the eye turns it off), is refused. A run of
    /// changes is one "<Kind>" step until `endAdjustLayer`; the whole canvas
    /// is damaged in this call. Ignored for a pixel layer or an unknown id.
    public mutating func adjustLayer(_ id: PhotoLayer.ID, _ edit: AdjustmentEdit) {
        guard let at = index(of: id), case .adjustment(let settings) = layers[at].kind,
            settings.isEnabled(edit.kind)
        else { return }
        if case .setEnabled = edit { return }
        var next = settings
        next.apply(edit)
        guard next != settings else { return }
        recordLayers(named: edit.kind.title, coalescing: "adjust-layer-\(id)-\(edit.kind.rawValue)")
        layers[at].kind = .adjustment(next)
        touch(.all)
    }

    /// Ends a slider or curve gesture on an adjustment layer: one history step
    /// per gesture, as `endAdjust` does for the whole image.
    public mutating func endAdjustLayer() { endAdjust() }

    /// The sections the inspector shows for the target, in order: the layer's
    /// own, or all five for the whole image.
    public var adjustSections: [AdjustmentKind] {
        switch adjustTarget {
        case .image: AdjustmentKind.allCases
        case .layer(_, let settings): AdjustmentKind.allCases.filter { settings.isEnabled($0) }
        }
    }

    /// "Image" or the layer's name, and the info line under it.
    public var adjustHeader: (title: String, info: String) {
        guard case .layer = adjustTarget, let layer = selectedLayer else {
            return ("Image", "Adjusts the whole image")
        }
        return (layer.name, "Adjusts the layers below")
    }

    /// The info line under a layer's row: "Nothing below to adjust." for an
    /// adjustment layer at the bottom of the stack; nil otherwise.
    public func layerInfo(_ id: PhotoLayer.ID) -> String? {
        guard let at = index(of: id), case .adjustment = layers[at].kind, at == layers.count - 1 else { return nil }
        return "Nothing below to adjust."
    }

    /// The blend mode and opacity at the end of layer `id`'s row, with the
    /// tooltip that names both; nil for a Normal layer at 100% or an unknown id.
    public func layerBlendSummary(_ id: PhotoLayer.ID) -> PhotoBlendSummary? {
        guard let at = index(of: id), layers[at].blendMode != .normal || layers[at].opacity < 1 else { return nil }
        let mode = layers[at].blendMode.title
        let percent = "\(Int(layers[at].opacityPercent.rounded()))%"
        return PhotoBlendSummary(text: "\(mode) \(percent)", help: "Blend mode \(mode), opacity \(percent)")
    }
}
