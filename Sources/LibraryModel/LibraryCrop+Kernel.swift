// LibraryCrop+Kernel.swift (orientation-crop OC-8): Library's image.rotate-*, image.flip and crop.*
// commands on the kernel's `CropCommands`. A photo's orientation lives in its develop settings and
// faces the pixels before the crop; a turn or flip carries the stored crop with the picture. The
// crop's bounds are the oriented photo's straightened canvas in pixels, so a ratio frames the photo
// as it stands, and a frame set with no draft open is stored as one named step. The loupe's crop
// draft lives here too (OC-z): Library keeps no crop copy of its own beside this adapter. Linux-safe.
import CoreRaster
import SuiteKernel

/// The catalog as the kernel's orientation and crop target (its own `cropFrame` and `applyCrop`
/// are the draft's, so the kernel's live here).
struct LibraryCropDocument: OrientationTarget, CropTarget {
    var library: LibraryCatalog
    /// The aspect crop.set-aspect asked for, stored with the frame so a drag holds it.
    var aspect: CropAspect?

    var orientationHelp: String? { library.services.unavailable["develop"] ?? library.developHelp }
    var orientation: Orientation { library.orientationTarget?.develop.orientation ?? .up }

    mutating func setOrientation(_ o: Orientation, name: String) throws {
        let delta = Orientation.allCases.first { orientation.then($0) == o } ?? .up
        let ids = library.developTargets
        library.cancelCrop()
        library.endDevelopDrag()
        library.recordEdit(name, ids: ids) { photo in
            let d = photo.develop
            photo.develop = d.setting(orientation: d.orientation.then(delta)).setting(crop: d.crop.map { $0.faced(delta) })
        }
        library.endDevelopDrag()
        for id in ids { library.invalidateThumbnail(id) }
    }

    var cropHelp: String? { library.cropHelp }

    /// The draft, else the stored crop, in the canvas's pixels.
    var cropFrame: CropFrame? {
        guard let photo = library.loupeItem, let crop = library.cropDraft ?? photo.develop.crop,
              let canvas = canvas(photo, angle: crop.angle) else { return nil }
        let r = crop.rect
        return CropFrame(rect: Rect(minX: r.x * canvas.width, minY: r.y * canvas.height,
                                    maxX: (r.x + r.width) * canvas.width, maxY: (r.y + r.height) * canvas.height), angle: crop.angle)
    }

    var cropBounds: Rect {
        guard let photo = library.loupeItem,
              let canvas = canvas(photo, angle: (library.cropDraft ?? photo.develop.crop)?.angle ?? 0) else { return Rect(minX: 0, minY: 0, maxX: 1, maxY: 1) }
        return Rect(minX: 0, minY: 0, maxX: canvas.width, maxY: canvas.height)
    }

    mutating func setCropFrame(_ f: CropFrame?, name: String) throws {
        guard let f else { return library.resetCrop() }
        guard let photo = library.loupeItem, let canvas = canvas(photo, angle: f.angle),
              canvas.width > 0, canvas.height > 0 else { return }
        let rect = UnitRect(x: f.rect.minX / canvas.width, y: f.rect.minY / canvas.height,
                            width: f.rect.width / canvas.width, height: f.rect.height / canvas.height)
        let kept = aspect ?? (library.cropDraft ?? photo.develop.crop)?.aspect ?? .free
        let crop = CropSettings(angle: f.angle, rect: rect, aspect: kept)
        guard library.cropDraft == nil else {
            library.cropDraft = crop
            return
        }
        let stored: CropSettings? = f.angle == 0 && rect == .full ? nil : crop
        library.recordEdit(name, ids: [photo.id]) { $0.develop = $0.develop.setting(crop: stored) }
        library.invalidateThumbnail(photo.id)
    }

    mutating func applyCrop() throws { if library.cropDraft != nil { library.applyCrop() } }

    /// The oriented photo's straightened canvas at `angle`, in pixels.
    private func canvas(_ photo: PhotoItem, angle: Double) -> (width: Double, height: Double)? {
        let whole = CropSettings(angle: angle, rect: .full, aspect: .original)
        return (try? library.services.crop.frame(whole, photo: photo.orientedSize)).map { (Double($0.width), Double($0.height)) }
    }

    static let catalog: CommandCatalog<LibraryCropDocument> =
        (try? CommandCatalog(app: "library", CropCommands.specs(LibraryCropDocument.self),
                             history: { LibraryCatalogSteps(catalog: $0.library) })) ?? .empty(app: "library")

    /// The nine specs on the catalog: each runs its kernel spec on the document and keeps the result.
    static let specs: [CommandSpec<LibraryCatalog>] = CropCommands.specs(LibraryCropDocument.self).map { spec in
        .typed(spec.id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: spec.params,
               result: spec.result, example: spec.example,
               availability: { spec.availability(LibraryCropDocument(library: $0)) }) { c, json in
            var doc = LibraryCropDocument(library: c, aspect: aspect(in: json))
            let outcome = try catalog.run(spec.id, params: json, on: &doc)
            c = doc.library
            return outcome.result
        }
    }

    /// crop.set-aspect's aspect, nil for any other params.
    private static func aspect(in json: JSONValue) -> CropAspect? {
        guard case .object(let fields) = json, case .string(let raw)? = fields["aspect"] else { return nil }
        return CropAspect(rawValue: raw)
    }
}

extension LibraryCatalog {
    /// The photo whose orientation the image commands read: the loupe photo, else the first selected.
    var orientationTarget: PhotoItem? {
        let ids = developTargets
        return items.first { ids.contains($0.id) }
    }
}

extension PhotoItem {
    /// The photo's size as it faces: a quarter turn swaps the sides.
    public var orientedSize: PixelSize {
        let s = develop.orientation.size(pixelSize.width, pixelSize.height)
        return PixelSize(width: s.width, height: s.height)
    }
}

extension CropSettings {
    /// This crop carried with its picture as `o` faces it: a mirror reflects the rect and its
    /// angle, then each clockwise quarter turns the rect.
    func faced(_ o: Orientation) -> CropSettings {
        var r = rect, a = angle
        let (turns, mirrored) = o.quarterTurns
        if mirrored { r.x = 1 - r.x - r.width; a = -a }
        for _ in 0..<turns { r = UnitRect(x: 1 - r.y - r.height, y: r.x, width: r.height, height: r.width) }
        return CropSettings(angle: a, rect: r, aspect: aspect)
    }
}

extension Orientation {
    /// Clockwise quarter turns after an optional left-right mirror, as EXIF's eight pair up.
    var quarterTurns: (turns: Int, mirrored: Bool) {
        switch self {
        case .up: (0, false)
        case .upMirrored: (0, true)
        case .right: (1, false)
        case .rightMirrored: (1, true)
        case .down: (2, false)
        case .downMirrored: (2, true)
        case .left: (3, false)
        case .leftMirrored: (3, true)
        }
    }
}

extension PixelBuffer {
    /// These pixels facing `o`: mirrored left to right first, then turned clockwise. Exact copies.
    func oriented(_ o: Orientation) -> PixelBuffer {
        let (turns, mirrored) = o.quarterTurns
        let m = mirrored ? flipped(.horizontal) : self
        switch turns {
        case 1: return m.rotated(.degrees90)
        case 2: return m.rotated(.degrees180)
        case 3: return m.rotated(.degrees270)
        default: return m
        }
    }
}

// MARK: The loupe photo's crop draft (crop CR-1, moved here from LibraryCrop.swift by OC-z, #3117)
//
// R opens a draft on the loupe photo (its stored crop, else Original at 0°); the aspect, handle
// drags and the straighten angle reshape it through `services.crop` and record nothing; Apply
// stores it as one "Crop" step and Cancel drops it. The crop is an instruction in
// `DevelopSettings`, never pixels. The kernel's crop.* commands above act on this same draft.

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
