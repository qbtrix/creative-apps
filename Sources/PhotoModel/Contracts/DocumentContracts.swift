// Contracts/DocumentContracts.swift: the layered document (PV-1). A document
// is one OpenRaster file (a zip, https://www.openraster.org/baseline/): the
// `mimetype` entry, `stack.xml` with the layers, one 8-bit sRGB PNG per pixel
// layer, `mergedimage.png` and `Thumbnails/thumbnail.png`, plus Photo's own
// `photo/document.json` for what OpenRaster has no word for (adjustment
// layers, masks, the whole-image adjustments). PNGs go through the
// PhotoImageCodec the app already has, so the format code runs and is tested
// on Linux. Recovery keeps the latest autosaved file. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// A document's entries by path: "mimetype", "stack.xml",
/// "data/layer-3.png", "photo/masks/layer-3.png", "photo/document.json",
/// "mergedimage.png", "Thumbnails/thumbnail.png".
public struct PhotoPackage: Sendable, Equatable {
    public var files: [String: Data]
    public init(files: [String: Data]) { self.files = files }
}

/// Everything a document keeps, in 8-bit straight-alpha sRGB like an opened
/// file. A mask is stored as a gray image whose gray is the coverage.
public struct PhotoDocumentSnapshot: Sendable, Equatable {
    public var canvas: CanvasSize
    /// Top first, with kind, mask flags, blend, opacity and offset.
    public var layers: [PhotoLayer]
    /// One image per pixel layer, its own size.
    public var pixels: [PhotoLayer.ID: DecodedImage]
    /// One image per layer that has a mask, the layer's size.
    public var masks: [PhotoLayer.ID: DecodedImage]
    /// The Adjust tab's whole-image adjustments.
    public var adjustments: AdjustmentSettings
    public var selectedLayerID: PhotoLayer.ID?
    public init(canvas: CanvasSize, layers: [PhotoLayer], pixels: [PhotoLayer.ID: DecodedImage],
                masks: [PhotoLayer.ID: DecodedImage] = [:], adjustments: AdjustmentSettings = AdjustmentSettings(),
                selectedLayerID: PhotoLayer.ID? = nil) {
        self.canvas = canvas; self.layers = layers; self.pixels = pixels; self.masks = masks
        self.adjustments = adjustments; self.selectedLayerID = selectedLayerID
    }
}

/// Why a package didn't open; `message` is the alert's text.
public enum ArchiveError: Error, Equatable, Sendable {
    case notADocument
    case newerVersion(Int)
    case damaged(String)
    case tooLarge

    public var message: String {
        switch self {
        case .notADocument: "This file isn't a Photo document."
        case .newerVersion(let v): "This document was made by a newer Photo (format \(v)). Update Photo to open it."
        case .damaged(let detail): "This document is damaged: \(detail)."
        case .tooLarge: "This document is larger than Photo can open."
        }
    }
}

/// PV-1: write and read the layered document.
public protocol DocumentArchiving: PhotoUseCase {
    /// The format version this conformance writes; a newer one fails to open.
    var formatVersion: Int { get }
    /// The package for `snapshot`, every image through `codec` as PNG.
    func encode(_ snapshot: PhotoDocumentSnapshot, codec: any PhotoImageCodec) throws -> PhotoPackage
    /// The snapshot in `package`. Throws `ArchiveError` and nothing else.
    func decode(_ package: PhotoPackage, codec: any PhotoImageCodec) throws -> PhotoDocumentSnapshot
    /// The file's bytes: a zip whose first entry is `mimetype`, every entry
    /// stored (PNGs are compressed already). Pure Swift, so Linux tests it.
    func container(_ package: PhotoPackage) throws -> Data
    /// The entries of a file `container` wrote. Throws `ArchiveError`
    /// (`.notADocument` for a non-zip or another mimetype, `.damaged` for a
    /// compressed entry, which v2 doesn't read).
    func package(fromContainer data: Data) throws -> PhotoPackage
}

/// One autosaved document.
public struct RecoveryEntry: Sendable, Equatable {
    /// The document's name when it had one, for "Restore <name> from <time>?".
    public var documentName: String?
    /// Seconds since 1970 when it was written.
    public var savedAt: Double
    public var package: PhotoPackage
    public init(documentName: String?, savedAt: Double, package: PhotoPackage) {
        self.documentName = documentName; self.savedAt = savedAt; self.package = package
    }
}

/// PV-1: keep the latest autosave of the open document until it is saved or
/// closed cleanly. One entry per window; a newer write replaces it.
public protocol RecoveryStoring: PhotoUseCase {
    func write(_ entry: RecoveryEntry, window: String) throws
    /// The entries a crash left behind, newest first.
    func leftBehind() throws -> [RecoveryEntry]
    func discard(window: String) throws
    func discardAll() throws
}

/// What the open file is, so Save knows what to write.
public enum PhotoFileKind: Hashable, Sendable {
    /// A layered Photo document.
    case document
    /// A flat image file in a format Photo writes (PNG, JPEG).
    case image(ImageFormat)
    /// A flat file Photo reads but doesn't write (HEIC before PV-8): Save is Save As.
    case readOnly
}

/// What File > Save does now.
public enum SaveAction: Hashable, Sendable {
    /// Write the document over its file.
    case writeDocument
    /// Write the flat image over its file (one pixel layer, no masks or adjustment layers).
    case writeImage(ImageFormat)
    /// The open file is flat but the image has layers: ask "Keep layers?"
    /// (Save as Photo Document, or Flatten into the file's format).
    case askKeepLayers(ImageFormat)
    /// A new or read-only image: Save As.
    case saveAs
}
