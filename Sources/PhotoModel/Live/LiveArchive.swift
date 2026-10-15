// Live/LiveArchive.swift: the live layered document (D-2 of photo-documents),
// an OpenRaster file (https://www.openraster.org/baseline/). Encode writes
// `mimetype`, one PNG per pixel layer at "data/layer-<i>.png" (i counts the
// stack from the bottom, 1 first), each mask at "photo/masks/layer-<i>.png",
// the composite as `mergedimage.png` and at most 256 px long (a box filter
// in linear light) as `Thumbnails/thumbnail.png`, `stack.xml` for other
// OpenRaster readers, and `photo/document.json` with what OpenRaster has no
// word for. Decode reads only
// the JSON and the images it names (stack.xml is written, never parsed back:
// the packet's "Reading" decision) and throws only ArchiveError. Both run
// the codec on every image at once, across the cores. The zip is PhotoZip's.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

struct LiveArchive: DocumentArchiving {
    static let documentPath = "photo/document.json"
    static let thumbnailSide = 256

    var unavailableHelp: String? { nil }
    var formatVersion: Int { 1 }

    func encode(_ snapshot: PhotoDocumentSnapshot, codec: any PhotoImageCodec) throws -> PhotoPackage {
        var files: [String: Data] = [PhotoZip.mimetype: PhotoZip.mimetypeValue]
        var images: [(path: String, image: DecodedImage)] = []
        var entries: [LayerEntry] = [], contents: [LayerContent] = []
        for (index, layer) in snapshot.layers.enumerated() {
            let number = snapshot.layers.count - index
            var src: String?, mask: String?
            if layer.kind == .pixels {
                guard let image = snapshot.pixels[layer.id] else { throw RasterError.invalid("\(layer.name) has no pixels") }
                let path = "data/layer-\(number).png"
                images.append((path, image))
                src = path
            }
            if let image = snapshot.masks[layer.id] {
                let path = "photo/masks/layer-\(number).png"
                images.append((path, image))
                mask = path
            }
            entries.append(LayerEntry(layer, src: src, mask: mask))
            // As the renderer lays it: a disabled mask is kept but not applied.
            contents.append(LayerContent(
                layer: layer, pixels: try snapshot.pixels[layer.id].map(Self.tiles),
                mask: layer.isMaskEnabled ? try snapshot.masks[layer.id].map(Self.tiles) : nil))
        }
        let picture = try LiveMerging().flatten(contents, canvas: snapshot.canvas, adjustments: snapshot.adjustments)
        let merged = DecodedImage(rgba8: try picture.rgba8(), width: picture.width, height: picture.height)
        let all = images + [("mergedimage.png", merged), ("Thumbnails/thumbnail.png", try Self.thumbnail(merged))]
        // Every PNG at once, across the cores.
        let pngs = try PhotoLayerComposite.inParallel(all.count) { try codec.encode(all[$0].image, as: .png, quality: 1) }
        for (entry, png) in zip(all, pngs) { files[entry.path] = png }
        files["stack.xml"] = Data(PhotoStackXML.stack(snapshot.canvas, entries).utf8)
        let document = DocumentEntry(
            format: formatVersion, canvas: SizeEntry(width: snapshot.canvas.width, height: snapshot.canvas.height),
            layers: entries, adjustments: snapshot.adjustments, selected: snapshot.selectedLayerID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        files[Self.documentPath] = try encoder.encode(document)
        return PhotoPackage(files: files)
    }

    func decode(_ package: PhotoPackage, codec: any PhotoImageCodec) throws -> PhotoDocumentSnapshot {
        guard let json = package.files[Self.documentPath] else { throw ArchiveError.damaged("\(Self.documentPath) is missing") }
        let unreadable = ArchiveError.damaged("\(Self.documentPath) is unreadable")
        guard let version = try? JSONDecoder().decode(VersionEntry.self, from: json) else { throw unreadable }
        guard version.format <= formatVersion else { throw ArchiveError.newerVersion(version.format) }
        guard let document = try? JSONDecoder().decode(DocumentEntry.self, from: json) else { throw unreadable }
        let canvas = CanvasSize(width: document.canvas.width, height: document.canvas.height)
        try Self.checkSize(canvas.width, canvas.height, what: "the canvas")
        @Sendable func image(_ path: String) throws -> DecodedImage {
            guard let data = package.files[path] else { throw ArchiveError.damaged("\(path) is missing") }
            guard let image = try? codec.decode(data, longestSide: nil) else { throw ArchiveError.damaged("\(path) is unreadable") }
            try Self.checkSize(image.width, image.height, what: path)
            return image
        }
        // Every image at once, across the cores; the first bad one in stack order throws.
        let paths = document.layers.flatMap { [$0.src, $0.mask].compactMap { $0 } }
        let decoded = try PhotoLayerComposite.inParallel(paths.count) { try image(paths[$0]) }
        let byPath = Dictionary(zip(paths, decoded)) { first, _ in first }
        var pixels: [PhotoLayer.ID: DecodedImage] = [:], masks: [PhotoLayer.ID: DecodedImage] = [:]
        var layers: [PhotoLayer] = []
        for entry in document.layers {
            if let src = entry.src { pixels[entry.id] = byPath[src] }
            if let mask = entry.mask { masks[entry.id] = byPath[mask] }
            layers.append(entry.layer)
        }
        return PhotoDocumentSnapshot(
            canvas: canvas, layers: layers, pixels: pixels, masks: masks, adjustments: document.adjustments,
            selectedLayerID: document.selected)
    }

    func container(_ package: PhotoPackage) throws -> Data { try PhotoZip.container(package) }

    func package(fromContainer data: Data) throws -> PhotoPackage { try PhotoZip.package(fromContainer: data) }

    /// `.tooLarge` past the most pixels an opened image keeps; `.damaged` for
    /// a size that isn't positive.
    private static func checkSize(_ width: Int, _ height: Int, what: String) throws {
        guard width > 0, height > 0 else { throw ArchiveError.damaged("\(what) has a bad size") }
        let (pixels, overflow) = width.multipliedReportingOverflow(by: height)
        guard !overflow, pixels <= PhotoWorkspace.maxOpenPixels else { throw ArchiveError.tooLarge }
    }

    private static func tiles(_ image: DecodedImage) throws -> TiledPixels {
        try TiledPixels(rgba8: image.rgba8, width: image.width, height: image.height)
    }

    /// `picture` with its longest side at most `thumbnailSide`, the aspect
    /// kept: a box filter in linear light, one pass over the merged bytes.
    private static func thumbnail(_ picture: DecodedImage) throws -> DecodedImage {
        let longest = max(picture.width, picture.height)
        guard longest > thumbnailSide else { return picture }
        let scale = Double(thumbnailSide) / Double(longest)
        let width = max(Int((Double(picture.width) * scale).rounded()), 1)
        let height = max(Int((Double(picture.height) * scale).rounded()), 1)
        return try SRGBBytes.thumbnail(picture, width: width, height: height) ?? picture
    }
}

// MARK: photo/document.json

private struct VersionEntry: Decodable { var format: Int }

private struct SizeEntry: Codable { var width: Int, height: Int }

private struct DocumentEntry: Codable {
    var format: Int
    var canvas: SizeEntry
    /// Top first.
    var layers: [LayerEntry]
    var adjustments: AdjustmentSettings
    var selected: String?
}

/// One layer as the JSON and stack.xml describe it.
struct LayerEntry: Codable {
    enum Kind: String, Codable { case pixels, adjustment }
    struct Offset: Codable { var x: Int, y: Int }

    var id: String
    var name: String
    var kind: Kind
    var adjustment: AdjustmentSettings?
    var visible: Bool
    var opacity: Double
    var blend: BlendMode
    var offset: Offset
    var src: String?
    var mask: String?
    var maskEnabled: Bool

    init(_ layer: PhotoLayer, src: String?, mask: String?) {
        id = layer.id; name = layer.name; visible = layer.isVisible; opacity = layer.opacity
        blend = layer.blendMode; offset = Offset(x: layer.offsetX, y: layer.offsetY)
        self.src = src; self.mask = mask; maskEnabled = layer.isMaskEnabled
        switch layer.kind {
        case .pixels: kind = .pixels
        case .adjustment(let settings): kind = .adjustment; adjustment = settings
        }
    }

    var layer: PhotoLayer {
        var layer = PhotoLayer(id: id, name: name, isVisible: visible, opacity: opacity, blendMode: blend)
        layer.offsetX = offset.x; layer.offsetY = offset.y
        if kind == .adjustment { layer.kind = .adjustment(adjustment ?? AdjustmentSettings()) }
        layer.hasMask = mask != nil
        layer.isMaskEnabled = maskEnabled
        return layer
    }
}
