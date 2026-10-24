// PhotoMask.swift: layer masks (PV-5, masks-clipping). The geometry hook: every
// change to a layer's size or place (crop, Image Size, rotate, straighten,
// delete, and PV-2's and PV-7's own edits) calls `layerGeometryChanged`, so
// each mask can keep the size and place of its layer; its body is empty until
// PK-5, apart from the counting test hook. Then the mask edits the Layer menu
// runs (add, delete, apply, enable, edit) with their reasons; until PK-5 each
// refuses as not built. Linux-safe.
import CoreRaster

/// A geometry change every layer's extras (its mask) must follow.
public enum LayerGeometryChange: Hashable, Sendable {
    case cropped(PixelRect)
    case resized(scaleX: Double, scaleY: Double)
    case rotated(QuarterTurn)
    case straightened(degrees: Double, crop: PixelRect)
    case flippedCanvas(FlipAxis)
    case transformed(LayerTransform)
    case flipped(FlipAxis)
    case duplicated(from: PhotoLayer.ID)
    case removed
}

extension PhotoWorkspace {
    /// Layer `id`'s geometry changed by `change`; PV-5 moves its mask along.
    mutating func layerGeometryChanged(_ id: PhotoLayer.ID, _ change: LayerGeometryChange) {
        geometryChangeCount += 1
        lastGeometryChange = (id, change)
    }
}

/// What a new mask starts as: white (shows the whole layer), black (hides it) or the selection's coverage.
public enum MaskStart: String, Codable, CaseIterable, Sendable {
    case reveal, hide, selection
}

extension PhotoWorkspace {
    static let notImageLayer = "Select an image layer first.", noMask = "This layer has no mask."
    static let hasMaskAlready = "This layer already has a mask.", noSelection = "Make a selection first."
    /// What the add/delete/apply/enable bodies wait on (masks-clipping PK-5).
    static let masksNotBuilt = NotBuilt(feature: "PK-5")

    /// Why Delete, Apply, Disable and Edit Mask can't act on the selected layer, or nil when they can.
    public var maskHelp: String? {
        guard canvas != nil else { return Self.noImage }
        guard let layer = selectedLayer, layer.kind == .pixels else { return Self.notImageLayer }
        guard layer.hasMask else { return Self.noMask }
        return Self.masksNotBuilt.help
    }

    /// Why a mask starting as `start` can't be added to the selected layer, or nil when it can.
    public func addMaskHelp(_ start: MaskStart) -> String? {
        guard canvas != nil else { return Self.noImage }
        guard let layer = selectedLayer, layer.kind == .pixels else { return Self.notImageLayer }
        guard !layer.hasMask else { return Self.hasMaskAlready }
        if start == .selection, selection == nil, selectionMask == nil { return Self.noSelection }
        return Self.masksNotBuilt.help
    }

    /// Adds a mask to the selected layer, starting as `start`, in one undo step.
    public mutating func addMask(_ start: MaskStart) throws {
        if let why = addMaskHelp(start) { throw PhotoRefusal(why) }
        throw Self.masksNotBuilt.refuse()
    }

    /// Deletes the selected layer's mask in one undo step.
    public mutating func deleteMask() throws {
        if let why = maskHelp { throw PhotoRefusal(why) }
        throw Self.masksNotBuilt.refuse()
    }

    /// Bakes the selected layer's mask into its pixels and drops the mask, in one undo step.
    public mutating func applyMask() throws {
        if let why = maskHelp { throw PhotoRefusal(why) }
        throw Self.masksNotBuilt.refuse()
    }

    /// Turns the selected layer's mask on or off, keeping it, in one undo step.
    public mutating func setMaskEnabled(_ enabled: Bool) throws {
        if let why = maskHelp { throw PhotoRefusal(why) }
        throw Self.masksNotBuilt.refuse()
    }

    /// Points the brush and eraser at the selected layer's mask (`on`) or its pixels. No undo step.
    public mutating func setEditsMask(_ on: Bool) {
        guard !on || maskHelp == nil else { return }
        editsMask = on
    }
}
