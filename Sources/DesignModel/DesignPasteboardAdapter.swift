// DesignPasteboardAdapter.swift (clipboard-interop CB-6): Design's Copy and Paste through the suite's
// coder (SuitePasteboardCoding). A copy is three representations in the coder's order: Design's own
// layer bytes (today's copySelection, so Design pastes them back as layers), an SVG of the selection
// (DesignSVG) and a PNG of the selection's bounds at 2x. The Model can't draw pixels, so the PNG
// comes from the renderer the adapter is given: the app passes DesignRasterizer; the default is a
// clear bitmap of the raster's size, which keeps Linux and the tests honest about the size only.
// A paste takes the coder's best item: own layers go to today's paste; a plain image or SVG is one
// new layer at its natural size (contain-fitted to the page, never upscaled) centred on the view's
// centre, selected, one "Paste" step. Until Design has a picture layer (design/placed-images PD-m)
// that layer is a rectangle named after the picture. DesignWorkspace is the catalog's CopyAsTarget
// here (`edit.copy-as`, `edit.paste-as-image`). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import SuiteModel

public struct DesignPasteboardAdapter {
    /// Draws a planned raster as PNG bytes.
    public typealias Renderer = (DesignRaster) throws -> Data
    /// The PNG's pixels per point.
    static let pngScale = 2

    let coder = SuitePasteboardCoding()
    let render: Renderer

    public init(png render: @escaping Renderer = DesignPasteboardAdapter.clearPNG) { self.render = render }

    /// The pictures Design pastes, best first: the coder's Design row kept to SVG and the registry's image
    /// formats (SuiteImageFormats), never its own layers, an envelope, text or a file URL. Paste as Image
    /// takes only these, and the window's Paste command accepts them beside Design's own type.
    public static let pictureTypes: [SuiteTypeID] = SuitePasteboardCoding.accepts[.design, default: []].filter { type in
        type == .svg || SuiteImageFormats.all.contains { $0.typeID == type }
    }

    /// The selection as own layers, SVG and PNG, in that order.
    public func copy(_ workspace: DesignWorkspace) throws(DesignRefusal) -> [TypedData] {
        let own = try workspace.copySelection()
        let art = try workspace.selectionArt()
        let raster = art.raster(scale: Self.pngScale)
        let png: Data
        do { png = try render(raster) } catch { throw .notYet("The selection couldn't be drawn as a PNG.") }
        return coder.representations(of: .appLayers(.designLayers, own))
            + coder.representations(of: .vector(svg: art.svg, name: art.name))
            + coder.representations(of: .image(png: png, pixelWidth: raster.pixelWidth, pixelHeight: raster.pixelHeight))
    }

    /// The best item from `offered`, pasted at `centre`; the coder's sentence when Design can't take any.
    public func paste(_ offered: [TypedData], into workspace: inout DesignWorkspace, centredOn centre: DesignPoint?) throws(DesignRefusal) {
        if let refusal = coder.pasteRefusal(for: offered, in: .design) { throw .notYet(refusal.message) }
        guard let item = coder.bestItem(from: offered, for: .design) else { throw .unreadable }
        try paste(item, into: &workspace, centredOn: centre)
    }

    /// Own layers through today's paste; an image or SVG as one picture layer centred on `centre`.
    public func paste(_ item: SuiteClipItem, into workspace: inout DesignWorkspace, centredOn centre: DesignPoint?) throws(DesignRefusal) {
        switch item {
        case .appLayers(.designLayers, let data): try workspace.paste(data)
        case .image(_, let width, let height):
            try workspace.placePicture("Pasted Image", natural: Size(width: Double(width), height: Double(height)), at: centre)
        case .vector(let svg, let name):
            guard let size = try? PlaceRules.vector(Data(svg.utf8), name: name).size else { throw .unreadable }
            try workspace.placePicture(name, natural: size, at: centre)
        default: throw .notYet(SuiteError.cannotPaste(app: .design, kind: item.kindName).message)
        }
    }

    /// A clear RGBA PNG of the raster's pixel size: stored deflate blocks, no drawing.
    public static func clearPNG(_ raster: DesignRaster) -> Data {
        let (width, height) = (max(1, raster.pixelWidth), max(1, raster.pixelHeight))
        let rows = [UInt8](repeating: 0, count: (1 + width * 4) * height)
        var zlib: [UInt8] = [0x78, 0x01]
        var at = 0
        repeat {
            let count = min(65_535, rows.count - at)
            zlib += [at + count == rows.count ? 1 : 0, UInt8(count & 0xFF), UInt8(count >> 8)]
            zlib += [UInt8(~count & 0xFF), UInt8((~count >> 8) & 0xFF)] + rows[at..<(at + count)]
            at += count
        } while at < rows.count
        zlib += word(UInt32(rows.count % 65_521) << 16 | 1)   // Adler-32 of zeros: a = 1, b = the count
        func chunk(_ type: String, _ body: [UInt8]) -> [UInt8] {
            let typed = Array(type.utf8) + body
            return word(UInt32(body.count)) + typed + word(crc(typed))
        }
        let header = word(UInt32(width)) + word(UInt32(height)) + [8, 6, 0, 0, 0]
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        return Data(signature + chunk("IHDR", header) + chunk("IDAT", zlib) + chunk("IEND", []))
    }

    static func word(_ value: UInt32) -> [UInt8] { [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) } }

    static let crcTable: [UInt32] = (0..<256).map { n in
        (0..<8).reduce(UInt32(n)) { c, _ in c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
    }

    static func crc(_ bytes: [UInt8]) -> UInt32 {
        ~bytes.reduce(UInt32.max) { c, byte in crcTable[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
    }
}

/// The selection as one piece of art: its layers, their bounds in whole points, and a name.
struct DesignSelectionArt {
    var nodes: [DesignNode]
    var box: DesignRect
    var name: String

    var svg: String { DesignSVG.document(nodes, box: box, clip: false) }

    /// The layers moved to the origin, on a page the box's size, at `scale` pixels per point.
    func raster(scale: Int) -> DesignRaster {
        let moved = nodes.map { node in
            var node = node
            node.translate(by: DesignPoint(x: -box.x, y: -box.y))
            return node
        }
        let page = DesignPage(id: "selection", name: name, frameWidth: box.width, frameHeight: box.height, nodes: moved)
        return DesignRaster(artwork: page, pixelWidth: Int(box.width) * scale, pixelHeight: Int(box.height) * scale, scale: scale)
    }
}

extension DesignWorkspace {
    /// The selected layers and their bounds, rounded out to whole points of at least one.
    func selectionArt() throws(DesignRefusal) -> DesignSelectionArt {
        guard let page = selectedPage else { throw .nothingSelected }
        let nodes = selectedNodeIDs.compactMap { page.nodes.node($0) }
        guard let first = nodes.first else { throw .nothingSelected }
        let x = nodes.map(\.frame.x).min() ?? 0, y = nodes.map(\.frame.y).min() ?? 0
        let maxX = nodes.map(\.frame.maxX).max() ?? x, maxY = nodes.map(\.frame.maxY).max() ?? y
        guard [x, y, maxX, maxY].allSatisfy(\.isFinite) else { throw .unchanged }
        let side = { (value: Double) in Double(Swift.min(DesignRaster.maxSide / 2, Swift.max(1, Int(value.rounded(.up))))) }
        let box = DesignRect(x: x, y: y, width: side(maxX - x), height: side(maxY - y))
        return DesignSelectionArt(nodes: nodes, box: box, name: nodes.count == 1 ? first.name : "Design Layers")
    }

    /// One new top-level layer named `name`, `natural` points contain-fitted to the page and centred on
    /// `centre` (else the page's centre), selected, as one `step` ("Paste" unless the command names its own).
    mutating func placePicture(_ name: String, natural: Size, at centre: DesignPoint?, step: String = "Paste") throws(DesignRefusal) {
        guard let page = selectedPage, editingTextID == nil, gesture == nil else { throw .unchanged }
        let canvas = Rect(minX: 0, minY: 0, maxX: page.frameWidth, maxY: page.frameHeight)
        let point = centre.map { Point(x: $0.x, y: $0.y) }
        let box = PlaceRules.fitted(natural: natural, in: canvas, at: point)
        var mint = mint()
        let node = DesignNode(id: mint.nextNodeID(), name: name, kind: .rectangle, frame: DesignRect(box))
        apply(DesignEdit(name: step, nodes: page.nodes + [node], selection: [node.id]), mint: mint)
    }
}

extension DesignWorkspace: CopyAsTarget {
    public var copyAsHelp: String? { copyHelp() }

    public var pasteAsImageHelp: String? {
        if let help = addPageHelp { return help }
        return editingTextID == nil ? nil : pasteHelp(nil)
    }

    /// Own and SVG bytes, and a PNG of the selection at 2x: here the adapter's clear bitmap of that size
    /// (the Model draws no pixels; the app's Copy As passes DesignRasterizer).
    public func copyAs(_ format: CopyAsFormat) throws -> CopiedBytes {
        switch format {
        case .own: return CopiedBytes(type: pasteboardType, data: try copySelection())
        case .svg: return CopiedBytes(type: SuiteTypeID.svg.rawValue, data: Data(try selectionArt().svg.utf8))
        case .png:
            let raster = try selectionArt().raster(scale: DesignPasteboardAdapter.pngScale)
            return CopiedBytes(type: SuiteTypeID.png.rawValue, data: DesignPasteboardAdapter.clearPNG(raster))
        }
    }

    /// An SVG, PNG or JPEG as one picture layer centred on the page. A PNG is known by its first four
    /// bytes and sized by its header (1 x 1 pt when the header is cut short); a JPEG, whose size the
    /// Model can't read, is refused with Place's sentence until placed-images reads it.
    public mutating func pasteAsImage(name: String, data: Data) throws {
        let size = PlaceRules.format(of: data) == .svg ? try PlaceRules.vector(data, name: name).size : Self.pngSize(data)
        guard let size else { throw DesignRefusal.notYet(PlaceRules.formatHelp) }
        try placePicture(name, natural: size, at: nil, step: "Paste as Image")
    }

    /// A PNG's size in points at 1x from its IHDR chunk; 1 x 1 when only the signature's start is there.
    static func pngSize(_ data: Data) -> Size? {
        let bytes = [UInt8](data.prefix(24))
        guard bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) else { return nil }
        guard bytes.count == 24 else { return Size(width: 1, height: 1) }
        let int = { (at: Int) in bytes[at..<(at + 4)].reduce(0) { $0 << 8 | Int($1) } }
        let (width, height) = (int(16), int(20))
        return width > 0 && height > 0 ? Size(width: Double(width), height: Double(height)) : Size(width: 1, height: 1)
    }
}
