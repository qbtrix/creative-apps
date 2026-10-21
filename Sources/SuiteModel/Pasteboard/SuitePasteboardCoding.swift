// SuitePasteboardCoding.swift (clipboard-interop CB-1 stub, CB-3 body): the live PasteboardCoding (UC-7) every app
// copies and pastes through. Pure and Linux-safe; SuiteShell's PasteboardBridge carries its `TypedData` to and
// from the system pasteboard, and the CLI's PasteboardFolder to and from a folder.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension SuiteTypeID {
    /// A TIFF image, what a screenshot or another app's copy often offers beside or instead of PNG.
    public static let tiff = SuiteTypeID(rawValue: "public.tiff")
}

/// The suite's pasteboard coder: each app takes its own layers first, then the richest picture it can place.
public struct SuitePasteboardCoding: PasteboardCoding {
    let fake = FakePasteboard()

    public init() {}

    /// What each app takes, best first. Photo places pixels, so an SVG is its last picture, after every image.
    public static let accepts: [SuiteApp: [SuiteTypeID]] = [
        .design: [.designLayers, .assetEnvelope, .svg, .png, .tiff, .jpeg, .heic, .plainText, .fileURL],
        .flare: [.flareLayers, .assetEnvelope, .svg, .png, .tiff, .jpeg, .heic, .plainText, .fileURL],
        .photo: [.assetEnvelope, .png, .tiff, .jpeg, .heic, .svg, .fileURL],
        .halo: [.assetEnvelope, .svg, .png, .tiff, .jpeg, .heic, .plainText, .fileURL],
        .library: [.png, .tiff, .jpeg, .heic, .fileURL],
        .launcher: [.fileURL, .assetEnvelope, .svg, .png, .tiff],
    ]

    /// Every type the suite reads, richest first: what a refusal names is the first of these on offer.
    static let richness: [SuiteTypeID] = [.designLayers, .flareLayers, .assetEnvelope, .svg, .png, .tiff, .jpeg,
                                          .heic, .plainText, .fileURL]

    /// Richest first: own layers, then SVG (vector items), then PNG, then TIFF (images), then text.
    public func representations(of item: SuiteClipItem) -> [TypedData] {
        fake.representations(of: item)
    }

    /// The best item `app` can take from what is offered, or nil. Another app's own layers are skipped.
    public func bestItem(from offered: [TypedData], for app: SuiteApp) -> SuiteClipItem? {
        for type in Self.accepts[app] ?? [] {
            guard let rep = offered.first(where: { $0.type == type }), let item = decode(rep, from: offered, for: app)
            else { continue }
            return item
        }
        return nil
    }

    /// nil when Paste can act in `app`; else why it is off, naming what the pasteboard holds.
    public func pasteRefusal(for offered: [TypedData], in app: SuiteApp) -> SuiteError? {
        if offered.isEmpty { return .nothingToPaste }
        if bestItem(from: offered, for: app) != nil { return nil }
        let richest = Self.richness.first { type in offered.contains { $0.type == type } }
        return .cannotPaste(app: app, kind: richest.map(Self.kindName) ?? "this")
    }

    /// The plural a refusal names for a type on offer.
    static func kindName(_ type: SuiteTypeID) -> String {
        switch type {
        case .designLayers, .flareLayers: "layers"
        case .assetEnvelope: "assets"
        case .svg: "vector art"
        case .plainText: "text"
        case .fileURL: "files"
        default: "images"
        }
    }

    /// One representation as the item `app` gets, or nil when it can't be read (the next type is tried).
    func decode(_ rep: TypedData, from offered: [TypedData], for app: SuiteApp) -> SuiteClipItem? {
        switch rep.type {
        case .designLayers, .flareLayers: return .appLayers(rep.type, rep.data)
        case .assetEnvelope:
            guard let e = try? JSONDecoder().decode(AssetEnvelope.self, from: rep.data) else { return nil }
            if e.kind == .image, app == .flare || app == .halo { return nil }   // a linked image places by its pixels
            return .envelope(e)
        case .svg: return .vector(svg: String(decoding: rep.data, as: UTF8.self), name: "Pasted art")
        case .png:
            let size = Self.pngSize(rep.data)
            return .image(png: rep.data, pixelWidth: size.width, pixelHeight: size.height)
        case .tiff, .jpeg, .heic: return .image(png: rep.data, pixelWidth: 0, pixelHeight: 0)
        case .plainText: return .text(String(decoding: rep.data, as: UTF8.self))
        case .fileURL:
            let refs = offered.filter { $0.type == .fileURL }.compactMap(fake.fileRef)
            return refs.isEmpty ? nil : .files(refs)
        default: return nil
        }
    }

    /// The pixel size in a PNG's IHDR chunk (big-endian width and height at bytes 16 and 20), or 0 by 0.
    static func pngSize(_ data: Data) -> (width: Int, height: Int) {
        let bytes = [UInt8](data.prefix(24))
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard bytes.count == 24, Array(bytes[0..<8]) == signature, bytes[12..<16].elementsEqual("IHDR".utf8)
        else { return (0, 0) }
        func int(_ at: Int) -> Int { bytes[at..<at + 4].reduce(0) { $0 << 8 | Int($1) } }
        return (int(16), int(20))
    }
}
