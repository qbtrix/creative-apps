// PhotoCropSize.swift: the crop tool's drag, typed fields and aspect lock
// (PV-3, #544; this file is PV-3's). The drag from the press to the pointer
// is the pending crop, keeping the locked aspect, and a click drops it; the
// four fields (X, Y, W, H) set it by number; an aspect lock reshapes it about
// its center and Swap turns 3:2 into 2:3. All the geometry is
// `services.crop`'s. None of this is an undo step: only Apply Crop records
// "Crop". Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    /// The crop's drag from the stroke's press to `end`, in canvas pixels.
    /// A click (under a pixel of travel) or a drag wholly off the canvas
    /// drops the pending crop.
    mutating func cropDrag(
        _ current: PhotoStroke, to end: Mask.Point, modifiers: DragModifiers, zoom: Double, in canvas: CanvasSize
    ) {
        guard Self.dragRect(current.start, end, in: canvas) != nil else {
            pendingCrop = nil
            return
        }
        pendingCrop = services.crop.dragged(from: current.start, to: end, aspect: cropAspect, canvas: canvas)
    }

    /// Whether the crop's fields take typing: a canvas is open and there is a
    /// pending crop or a locked aspect to start one from.
    public var cropFieldsEnabled: Bool { canvas != nil && (pendingCrop != nil || cropAspect != .free) }

    /// Sets one of the pending crop's numbers, clamped to the canvas and
    /// keeping the aspect lock. With no pending crop but a locked aspect it
    /// starts from the largest centered crop of that aspect. False, and
    /// nothing changes, for a value under 1 or when the fields are disabled.
    @discardableResult
    public mutating func setCropField(_ field: CropField, to value: Int) -> Bool {
        guard value >= 1, let canvas, cropFieldsEnabled else { return false }
        let crop = pendingCrop ?? services.crop.applying(cropAspect, to: nil, canvas: canvas)
        pendingCrop = services.crop.setting(field, to: value, in: crop, aspect: cropAspect, canvas: canvas)
        return true
    }

    /// The number a crop field shows: the pending crop's, or nil (the field
    /// shows its placeholder) with none.
    public func cropFieldValue(_ field: CropField) -> Int? {
        guard let crop = pendingCrop else { return nil }
        switch field {
        case .x: return crop.x
        case .y: return crop.y
        case .width: return crop.width
        case .height: return crop.height
        }
    }

    /// The text of the crop overlay's aspect pill ("3:2", "Original"); nil
    /// when the crop is free or there is no pending crop.
    public var cropAspectBadge: String? {
        guard pendingCrop != nil, cropAspect != .free else { return nil }
        return cropAspect.title
    }

    /// Locks the crop to `aspect`. A locked aspect reshapes the pending crop
    /// about its center (or starts the largest centered one); Free leaves it.
    public mutating func setCropAspect(_ aspect: CropAspect) {
        cropAspect = aspect
        reapplyCropAspect()
    }

    /// Swaps the locked aspect's sides (3:2 becomes 2:3) and reshapes the
    /// pending crop to it.
    public mutating func swapCropAspect() {
        guard let canvas else { return }
        cropAspect = services.crop.swapped(cropAspect, canvas: canvas)
        reapplyCropAspect()
    }

    private mutating func reapplyCropAspect() {
        guard cropAspect != .free, let canvas else { return }
        pendingCrop = services.crop.applying(cropAspect, to: pendingCrop, canvas: canvas)
    }
}
