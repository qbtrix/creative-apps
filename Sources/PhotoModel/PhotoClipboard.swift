// PhotoClipboard.swift: the workspace's Cut, Copy and Paste (PV-2). Copy hands
// `services.clipboard` the selected layer's pixels inside the selection (the
// whole layer with none) and the selection mask, and returns what it took for
// the window to put on the pasteboard; a fully transparent area gives
// "Nothing to copy." and the selected layer's name in the status line in
// that same call. Cut copies, then
// clears that area weighted by the selection's coverage, as one "Cut" step.
// Paste puts an image in a new "Pasted Layer" above the selected layer, where
// `services.clipboard.placement` says, and selects it: one "Paste" step. With
// no image open it opens the pasted image instead, as a new clean "Untitled"
// image. A pasted image over `maxOpenPixels` is scaled to fit (lanczos3),
// each side rounded down, with "Pasted at <n>%." in the status line. The
// bytes decode tile by tile across the cores (`decoded`).
// Contracts never record undo; the steps here do. Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    /// Why Copy can't run, or nil: no image, an adjustment layer selected, or
    /// a clipboard that isn't built. No selection copies the whole layer.
    public var copyHelp: String? {
        guard canvas != nil else { return "Open an image first." }
        guard let id = selectedLayerID, pixels[id] != nil else { return "Select a pixel layer first." }
        return services.clipboard.unavailableHelp
    }

    /// Why Cut can't run, or nil; the same reasons as Copy.
    public var cutHelp: String? { copyHelp }

    /// Why Paste can't run, or nil. It works with no image open: it opens one.
    public func pasteHelp(_ pasteboardHasImage: Bool) -> String? {
        pasteboardHasImage ? services.clipboard.unavailableHelp : "Nothing to paste."
    }

    /// The selected layer's pixels inside the selection, for the pasteboard.
    /// Nil when Copy can't run, or with "Nothing to copy." and the layer's
    /// name in `statusMessage` when every pixel there is transparent.
    public mutating func copySelection() -> ClipboardImage? {
        guard copyHelp == nil, let layer = selectedLayer, let tiled = pixels[layer.id] else { return nil }
        let content = PlacedPixels(pixels: tiled, x: layer.offsetX, y: layer.offsetY)
        do {
            if let image = try services.clipboard.copy(content, selection: selection, mask: selectionMask) {
                return image
            }
            statusMessage = nothingToCopy(layer)
        } catch let refusal as PhotoRefusal {
            statusMessage = refusal.message
        } catch {
            statusMessage = nothingToCopy(layer)
        }
        return nil
    }

    /// Why Copy took nothing: it reads only the selected layer, so the
    /// message names it, e.g. "Nothing to copy. The selected area of
    /// “Layer 1” is empty." (without a selection, "“Layer 1” is empty.").
    func nothingToCopy(_ layer: PhotoLayer) -> String {
        selection == nil
            ? "Nothing to copy. “\(layer.name)” is empty."
            : "Nothing to copy. The selected area of “\(layer.name)” is empty."
    }

    /// Copies, then clears what was copied from the selected layer, weighted
    /// by the selection's coverage: one "Cut" step. Nil, changing nothing but
    /// the status line, when Copy took nothing.
    public mutating func cutSelection() -> ClipboardImage? {
        guard let image = copySelection(), let id = selectedLayerID, let at = index(of: id),
            let tiled = pixels[id]
        else { return nil }
        if selection != nil {
            editSelection(named: "Cut") { _ in .clear }
        } else if let clear = try? TiledPixels(width: tiled.width, height: tiled.height) {
            // No selection: the whole layer.
            let before = Dictionary(uniqueKeysWithValues: tiled.tiles.enumerated().map { ($0.offset, $0.element) })
            record(.tiles(layer: id, before), named: "Cut")
            pixels[id] = clear
            touch(.region(
                PixelRect(x: layers[at].offsetX, y: layers[at].offsetY, width: tiled.width, height: tiled.height)))
        }
        return image
    }

    /// Pastes `image` as "Pasted Layer" above the selected layer and selects
    /// it, placed by the clipboard (on its source rect, else centered on
    /// `viewCenter`, canvas pixels): one "Paste" step. With no image open it
    /// opens `image` as a new clean image. Scaled to fit `maxOpenPixels` with
    /// a "Pasted at <n>%." note when larger. A help that isn't nil, or bytes
    /// that don't make an image, change only the status line.
    public mutating func paste(_ image: ClipboardImage, viewCenter: Mask.Point) {
        if let help = pasteHelp(true) {
            statusMessage = help
            return
        }
        guard let (tiles, percent) = try? Self.pastedPixels(image.image) else {
            statusMessage = "Can't paste this image."
            return
        }
        let note = percent.map { "Pasted at \($0)%." }
        guard let canvas else {
            start(with: tiles, name: nil)
            statusMessage = note
            return
        }
        // Placement reads only the size and source; a scaled paste has no
        // source to go back to.
        let fitted = percent == nil ? image : ClipboardImage(
            image: DecodedImage(rgba8: [], width: tiles.width, height: tiles.height), source: nil)
        let rect = services.clipboard.placement(of: fitted, canvas: canvas, center: viewCenter)
        record(.stack(stackState), named: "Paste")
        let above = selectedLayerID.flatMap(index(of:)) ?? 0
        let id = insertLayer(named: "Pasted Layer", pixels: tiles, kind: .pixels, at: above)
        if let at = index(of: id) {
            layers[at].offsetX = rect.x
            layers[at].offsetY = rect.y
        }
        selectedLayerID = id
        statusMessage = note
        touch(.all)
    }

    /// Test hook: while set (`$pasteLimit.withValue`), the most pixels a
    /// paste keeps, in place of `maxOpenPixels`, so the scaled path runs on a
    /// small image (a 24 MP lanczos3 resize takes minutes in a debug build).
    @TaskLocal static var pasteLimit = maxOpenPixels

    /// `image` as premultiplied pixels, scaled to fit `pasteLimit` (each side
    /// rounded down) when larger, with the scale in whole percent then.
    static func pastedPixels(_ image: DecodedImage) throws -> (TiledPixels, percent: Int?) {
        guard let size = pasteSize(width: image.width, height: image.height, limit: pasteLimit) else {
            return (try decoded(image), nil)
        }
        let buffer = try PixelBuffer(rgba8: image.rgba8, width: image.width, height: image.height)
        let resized = try buffer.resized(width: size.width, height: size.height, filter: .lanczos3)
        return (TiledPixels(resized), size.percent)
    }

    /// `image` decoded to premultiplied pixels, tile by tile across the cores;
    /// the decode is per pixel, so these are `PixelBuffer(rgba8:)`'s tiles.
    static func decoded(_ image: DecodedImage) throws -> TiledPixels {
        let (width, height, bytes) = (image.width, image.height, image.rgba8)
        let pixels = try PixelBuffer.validatedSize(width: width, height: height)
        // A wrong byte count gets CoreRaster's own refusal.
        guard bytes.count == pixels * 4 else {
            return TiledPixels(try PixelBuffer(rgba8: bytes, width: width, height: height))
        }
        var tiled = try TiledPixels(width: width, height: height)
        let grid = tiled
        tiled.tiles = try PhotoLayerComposite.inParallel(grid.tiles.count) { index in
            let rect = grid.tileRect(index)
            var part: [UInt8] = []
            part.reserveCapacity(rect.width * rect.height * 4)
            for y in rect.y..<rect.maxY {
                let start = (y * width + rect.x) * 4
                part.append(contentsOf: bytes[start..<(start + rect.width * 4)])
            }
            return try PixelBuffer(rgba8: part, width: rect.width, height: rect.height)
        }
        return tiled
    }

    /// The size a `width` x `height` paste is scaled to and its scale in whole
    /// percent, or nil when it fits `limit` pixels as it is.
    static func pasteSize(width: Int, height: Int, limit: Int = maxOpenPixels)
        -> (width: Int, height: Int, percent: Int)?
    {
        guard width > 0, height > 0, limit > 0 else { return nil }
        let area = Double(width) * Double(height)
        guard area > Double(limit) else { return nil }
        let scale = (Double(limit) / area).squareRoot()
        let w = max(Int((Double(width) * scale).rounded(.down)), 1)
        let h = max(Int((Double(height) * scale).rounded(.down)), 1)
        return (w, h, Int((scale * 100).rounded()))
    }
}
