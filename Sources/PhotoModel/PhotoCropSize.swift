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
    /// nothing changes, for an X or Y under 0, a W or H under 1, or when the
    /// fields are disabled.
    @discardableResult
    public mutating func setCropField(_ field: CropField, to value: Int) -> Bool {
        let lowest = field == .x || field == .y ? 0 : 1
        guard value >= lowest, let canvas, cropFieldsEnabled else { return false }
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

// MARK: The crop options' text (photo-crop, Anatomy rounds 1 and 2)

extension PhotoWorkspace {
    /// The one reason the caption, the fields and Apply give with no crop.
    private static let startCropReason = "Drag on the image, or pick a ratio below, to start a crop."

    /// The number a crop field draws: the pending crop's; with none, the
    /// whole image's rect (X 0, Y 0, W and H the canvas's), the crop that
    /// nothing pending means; 0 with no image.
    public func cropFieldDisplay(_ field: CropField) -> Int {
        if let value = cropFieldValue(field) { return value }
        guard let canvas else { return 0 }
        switch field {
        case .x, .y: return 0
        case .width: return canvas.width
        case .height: return canvas.height
        }
    }

    /// What VoiceOver and XCUI read as a crop field row's value: the number
    /// it draws, spoken with its unit ("600 pixels", "1 pixel"), as ScrubField
    /// speaks it, since the combined row carries no value of its own.
    public func cropFieldAccessibilityValue(_ field: CropField) -> String {
        let number = cropFieldDisplay(field)
        return "\(number) \(number == 1 ? "pixel" : "pixels")"
    }

    /// The crop options' one instruction line, always shown so nothing moves
    /// when a crop appears: what to do with no crop, else the crop's size and
    /// shape ("Crop 400 × 600 px, 2:3"), so a swapped ratio reads as such.
    public var cropCaption: String {
        guard canvas != nil else { return "Open an image to crop it." }
        guard let crop = pendingCrop else {
            return cropAspect == .free ? Self.startCropReason : "Drag on the image, or type a size."
        }
        return "Crop \(crop.width) × \(crop.height) px, \(cropAspect.title)"
    }

    /// Why Swap can't act, or nil when it turns the locked ratio's sides.
    public var cropSwapHelp: String? {
        guard canvas != nil else { return "Open an image to crop first." }
        switch cropAspect {
        case .free: return "Free has no fixed shape to swap."
        case .original: return "Original keeps the image's own shape."
        case .ratio(let w, let h): return w == h ? "A square crop is the same both ways." : nil
        }
    }

    /// Swap's title, which is also its tooltip while it acts: the change it
    /// makes ("Swap to 2:3" under 3:2), else "Swap Width and Height".
    public var cropSwapTitle: String {
        guard cropSwapHelp == nil, case .ratio(let w, let h) = cropAspect else { return "Swap Width and Height" }
        return "Swap to \(CropAspect.ratio(h, w).title)"
    }

    /// Why the four crop fields take no typing, or nil when they do.
    public var cropFieldsUnavailableHelp: String? {
        guard canvas != nil else { return "Open an image to crop first." }
        return cropFieldsEnabled ? nil : Self.startCropReason
    }

    /// Why one crop field takes no typing, or nil when it does: the fields'
    /// shared reason, else X (Y) when the crop typing would move already
    /// spans the image's full width (height), so any value snaps back to 0.
    public func cropFieldUnavailableHelp(_ field: CropField) -> String? {
        if let reason = cropFieldsUnavailableHelp { return reason }
        guard let canvas else { return nil }
        let crop = pendingCrop ?? services.crop.applying(cropAspect, to: nil, canvas: canvas)
        switch field {
        case .x: return crop.width >= canvas.width ? "The crop already spans the image's full width." : nil
        case .y: return crop.height >= canvas.height ? "The crop already spans the image's full height." : nil
        case .width, .height: return nil
        }
    }

    /// Why Apply Crop can't act, or nil while a crop that changes the image is pending.
    public var cropApplyHelp: String? {
        guard let canvas else { return "Open an image to crop first." }
        guard pendingCrop != nil else { return Self.startCropReason }
        return pendingCrop == canvas.rect ? "The crop covers the whole image." : nil
    }

    /// Why Cancel can't act, or nil while a crop is pending.
    public var cropCancelHelp: String? {
        guard canvas != nil else { return "Open an image to crop first." }
        return pendingCrop == nil ? "No crop to cancel." : nil
    }

    /// The aspect chips' tooltip: what a lock does and the image's own ratio.
    public var cropAspectGroupHelp: String {
        guard let ratio = originalRatio else { return "Open an image to choose a crop ratio." }
        return "Lock the crop to a ratio, width to height. Original keeps the image's own \(ratio)."
    }

    /// The tooltip of an enabled crop field: what its number measures.
    public func cropFieldHelp(_ field: CropField) -> String {
        switch field {
        case .x: "Left edge, in pixels from the image's left side"
        case .y: "Top edge, in pixels from the image's top"
        case .width: "Crop width in pixels"
        case .height: "Crop height in pixels"
        }
    }

    /// What an aspect chip locks to; Original names the image's own reduced
    /// ratio ("The image's own proportions (4:3).").
    public func cropAspectHelp(_ aspect: CropAspect) -> String {
        switch aspect {
        case .free: return "Any shape."
        case .ratio(let w, let h): return "Width to height \(w):\(h)."
        case .original:
            guard let ratio = originalRatio else { return "The image's own proportions." }
            return "The image's own proportions (\(ratio))."
        }
    }

    /// The canvas's reduced width to height ("4:3"); nil with no image.
    private var originalRatio: String? {
        guard let canvas, canvas.width > 0, canvas.height > 0 else { return nil }
        let divisor = Self.greatestCommonDivisor(canvas.width, canvas.height)
        return "\(canvas.width / divisor):\(canvas.height / divisor)"
    }

    /// The greatest common divisor of two sides, at least 1 so it divides safely.
    private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var (a, b) = (abs(a), abs(b))
        while b != 0 { (a, b) = (b, a % b) }
        return max(a, 1)
    }
}
