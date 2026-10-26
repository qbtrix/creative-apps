// LibraryCrop+Kernel.swift (orientation-crop OC-8): Library's image.rotate-*, image.flip and crop.*
// commands on the kernel's `CropCommands`. A photo's orientation lives in its develop settings and
// faces the pixels before the crop; a turn or flip carries the stored crop with the picture. The
// crop's bounds are the oriented photo's straightened canvas in pixels, so a ratio frames the photo
// as it stands, and a frame set with no draft open is stored as one named step. Linux-safe.
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
