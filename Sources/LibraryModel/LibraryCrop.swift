// LibraryCrop.swift: the loupe photo's crop draft in LibraryCatalog (crop
// CR-1). R opens a draft on the loupe photo (its stored crop, else Original
// at 0°); the aspect, handle drags and the straighten angle reshape it
// through `services.crop` and record nothing; Apply stores it as one "Crop"
// step and Cancel drops it. The crop is an instruction in `DevelopSettings`,
// never pixels. Library-local until the SuiteKernel crop lift (#3117).
// Linux-safe.

extension LibraryCatalog {
    /// Why Crop can't start: the services' "crop" reason, "Open a photo in the
    /// loupe to crop it.", "This photo has no pixel size."; nil when it can.
    public var cropHelp: String? {
        if let reason = services.unavailable["crop"] { return reason }
        guard let photo = loupeItem else { return "Open a photo in the loupe to crop it." }
        return photo.pixelSize.width > 0 && photo.pixelSize.height > 0 ? nil : "This photo has no pixel size."
    }

    /// "Done Cropping" while a draft is open, else "Crop".
    public var cropTitle: String { cropDraft == nil ? "Crop" : "Done Cropping" }

    /// A draft on the loupe photo: its stored crop, else Original at 0°. Records nothing.
    public mutating func beginCrop() {
        guard cropHelp == nil, let photo = loupeItem else { return }
        cropDraft = photo.develop.crop ?? (try? services.crop.initial(aspect: .original, angle: 0, photo: photo.pixelSize))
    }

    /// R and Photo > Crop: begins, or applies while cropping.
    public mutating func toggleCrop() {
        if cropDraft == nil { beginCrop() } else { applyCrop() }
    }

    /// `services.crop.initial(aspect, draft angle)`: centered, as large as fits.
    public mutating func setCropAspect(_ aspect: CropAspect) {
        guard let draft = cropDraft, let size = loupeItem?.pixelSize else { return }
        cropDraft = (try? services.crop.initial(aspect: aspect, angle: draft.angle, photo: size)) ?? draft
    }

    /// Handle drags and arrow nudges, in photo pixels. Records nothing.
    public mutating func dragCrop(_ handle: CropHandle, dx: Double, dy: Double) {
        guard dx.isFinite, dy.isFinite, let draft = cropDraft, let size = loupeItem?.pixelSize else { return }
        cropDraft = (try? services.crop.dragged(draft, handle: handle, dx: dx, dy: dy, photo: size)) ?? draft
    }

    /// Clamped to `CropSettings.angleRange`; NaN and infinity change nothing.
    public mutating func setCropAngle(_ degrees: Double) {
        guard degrees.isFinite, let draft = cropDraft, let size = loupeItem?.pixelSize else { return }
        let range = CropSettings.angleRange
        let angle = min(max(degrees, range.lowerBound), range.upperBound)
        cropDraft = (try? services.crop.straightened(draft, angle: angle, photo: size)) ?? draft
    }

    /// Adds a `levelAngle` result to the draft's angle; nil changes nothing.
    public mutating func levelCrop(by delta: Double?) {
        guard let delta, let draft = cropDraft else { return }
        setCropAngle(draft.angle + delta)
    }

    /// Stores the draft on the loupe photo as one "Crop" step (angle 0 with
    /// the whole rect stores nil), closes it, and drops the photo's thumbnail.
    public mutating func applyCrop() {
        guard let draft = cropDraft, let id = loupeItem?.id else { return }
        let stored: CropSettings? = draft.angle == 0 && draft.rect == .full ? nil : draft
        recordEdit("Crop", ids: [id]) { $0.develop = $0.develop.setting(crop: stored) }
        cropDraft = nil
        invalidateThumbnail(id)
    }

    /// Closes the draft. Records nothing.
    public mutating func cancelCrop() { cropDraft = nil }

    /// While cropping: the draft back to Original at 0°, no step. Otherwise
    /// the loupe photo's crop cleared as one "Reset Crop" step.
    public mutating func resetCrop() {
        if let draft = cropDraft {
            guard let size = loupeItem?.pixelSize else { return }
            cropDraft = (try? services.crop.initial(aspect: .original, angle: 0, photo: size)) ?? draft
            return
        }
        guard let id = loupeItem?.id, resetCropHelp == nil else { return }
        recordEdit("Reset Crop", ids: [id]) { $0.develop = $0.develop.setting(crop: nil) }
        invalidateThumbnail(id)
    }

    /// "This photo isn't cropped." with nothing to reset; nil when Reset Crop can act.
    public var resetCropHelp: String? {
        if cropDraft != nil { return nil }
        guard let photo = loupeItem else { return "Open a photo in the loupe to crop it." }
        return photo.develop.crop == nil ? "This photo isn't cropped." : nil
    }

    /// The draft's frame in the straightened photo's pixels; nil when not cropping.
    public var cropFrame: PixelRect? {
        guard let draft = cropDraft, let photo = loupeItem else { return nil }
        return try? services.crop.frame(draft, photo: photo.pixelSize)
    }

    /// The straightened photo's size (the frame of the whole rect); nil when not cropping.
    public var cropCanvas: PixelSize? {
        guard let draft = cropDraft, let photo = loupeItem else { return nil }
        let whole = CropSettings(angle: draft.angle, rect: .full, aspect: .original)
        return (try? services.crop.frame(whole, photo: photo.pixelSize)).map { PixelSize(width: $0.width, height: $0.height) }
    }

    /// `library.crop.frame`'s value: "4000 × 4000 at 1000, 0".
    public var cropFrameValue: String? {
        cropFrame.map { "\($0.width) × \($0.height) at \($0.x), \($0.y)" }
    }

    /// What the loupe renders while cropping: the photo's tone, the draft's
    /// angle, the whole straightened photo. Nil when not cropping.
    public var cropLoupeSettings: DevelopSettings? {
        guard let draft = cropDraft, let photo = loupeItem else { return nil }
        return photo.develop.setting(crop: CropSettings(angle: draft.angle, rect: .full, aspect: draft.aspect))
    }

    /// `photo`'s size after its stored crop; its own size without one.
    public func croppedSize(_ photo: PhotoItem) -> PixelSize {
        guard let crop = photo.develop.crop,
              let frame = try? services.crop.frame(crop, photo: photo.pixelSize) else { return photo.pixelSize }
        return PixelSize(width: frame.width, height: frame.height)
    }
}
