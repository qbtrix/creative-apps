// PhotoDocumentFile.swift: the workspace side of documents (PV-1). What the
// open file is (`fileKind(forName:)`: ".ora" is a document, a name
// ImageFormat maps is a flat image Photo writes, anything else read-only),
// what File > Save does with it (`saveAction`), whether the image needs a
// document to keep what it has (`needsDocument`), the window's save status,
// and the round trip: `snapshot()` turns the image into 8-bit straight-alpha
// sRGB like an opened file, `documentPackage` encodes it through a
// DocumentArchiving, `openDocument` decodes one and starts the image with
// every layer, mask, kind and the adjustments, clean and with nothing to undo.
// A failed open leaves the workspace as it was. `openDocument(_:name:)`
// takes a snapshot the window decoded off the main actor, and
// `PhotoServices.recovering(in:)` keeps autosaves in another folder. Both
// directions convert tile by tile across the cores (TiledPixelsBytes.swift).
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// The save status the window shows (its subtitle and status slot).
public enum PhotoSaveStatus: Hashable, Sendable, CaseIterable {
    case saved, edited, editedAutosaved, notSaved

    public var title: String {
        switch self {
        case .saved: "Saved"
        case .edited: "Edited"
        case .editedAutosaved: "Edited, autosaved"
        case .notSaved: "Not saved"
        }
    }
}

extension PhotoWorkspace {
    /// The kind of an opened file: .document for "ora", .image(f) for a name
    /// ImageFormat maps, else .readOnly. Case doesn't matter.
    public static func fileKind(forName name: String) -> PhotoFileKind {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count > 1, parts.last?.lowercased() == "ora" { return .document }
        guard parts.count > 1, let format = ImageFormat(fileName: name) else { return .readOnly }
        return .image(format)
    }

    /// What the image needs to keep: more than one layer, a mask or an adjustment layer.
    public var needsDocument: Bool {
        layers.count > 1 || !masks.isEmpty || layers.contains { $0.hasMask || $0.kind != .pixels }
    }

    /// What File > Save does now: write the document, write the flat file, ask
    /// "Keep layers?" for a flat file whose image has layers, or Save As.
    public var saveAction: SaveAction {
        switch fileKind {
        case .document: .writeDocument
        case .image(let format): needsDocument ? .askKeepLayers(format) : .writeImage(format)
        case .readOnly, nil: .saveAs
        }
    }

    /// The window's save status: nil with no image; "Saved" when clean; once
    /// edited, "Not saved" after a failed save, "Edited, autosaved" after an
    /// autosave of the latest edit, else "Edited". It reads `isDirty`, so it
    /// changes in the same call that edits or saves.
    public func saveStatus(autosaved: Bool, saveFailed: Bool) -> PhotoSaveStatus? {
        guard canvas != nil else { return nil }
        guard isDirty else { return .saved }
        if saveFailed { return .notSaved }
        return autosaved ? .editedAutosaved : .edited
    }

    /// Opens a flat file through `open(_:name:codec:longestSide:)` and sets
    /// `fileKind` from its name, so a just-opened PNG saves in place.
    public mutating func openImage(
        _ data: Data, name: String, codec: some PhotoImageCodec, longestSide: Int? = nil
    ) throws {
        try open(data, name: name, codec: codec, longestSide: longestSide)
        fileKind = Self.fileKind(forName: name)
    }

    /// The name Save as Photo Document offers: the document's name with
    /// ".ora" ("beach.png" is "beach.ora"); "Untitled.ora" for a new image.
    public var documentFileName: String {
        // fileName(for: .png) always ends in ".png".
        String(fileName(for: .png).dropLast(4)) + ".ora"
    }

    /// The file was written as `name`, of `kind`: the image is clean at this
    /// step and Save writes that kind from now on. Not an undo step; ignored
    /// with no image open.
    public mutating func didSave(as name: String, kind: PhotoFileKind) {
        guard canvas != nil else { return }
        documentName = name
        fileKind = kind
        savedStepID = currentStepID
    }

    /// The open image as a document keeps it: every layer (top first), each
    /// pixel layer's and mask's pixels as 8-bit straight-alpha sRGB, the
    /// whole-image adjustments and the selected layer. Throws
    /// `RasterError.invalid` with no image open.
    public func snapshot() throws -> PhotoDocumentSnapshot {
        guard let canvas else { throw RasterError.invalid("no image is open") }
        func image(_ tiles: TiledPixels) throws -> DecodedImage {
            DecodedImage(rgba8: try tiles.rgba8(), width: tiles.width, height: tiles.height)
        }
        return PhotoDocumentSnapshot(
            canvas: canvas, layers: layers, pixels: try pixels.mapValues(image), masks: try masks.mapValues(image),
            adjustments: adjustments, selectedLayerID: selectedLayerID)
    }

    /// The open image's document package, encoded through `archive`.
    public func documentPackage(archive: any DocumentArchiving, codec: any PhotoImageCodec) throws -> PhotoPackage {
        try archive.encode(snapshot(), codec: codec)
    }

    /// The open image's document package, through `services.archive`.
    public func documentPackage(codec: any PhotoImageCodec) throws -> PhotoPackage {
        try documentPackage(archive: services.archive, codec: codec)
    }

    /// Opens the document in `package`, named `name`, through
    /// `services.archive`.
    public mutating func openDocument(_ package: PhotoPackage, name: String, codec: any PhotoImageCodec) throws {
        try openDocument(package, name: name, archive: services.archive, codec: codec)
    }

    /// Opens the document in `package`, named `name`: every layer with its
    /// kind, mask, blend, opacity and offset, the adjustments and the selected
    /// layer; clean, with "Open" as the only history step. New layers get ids
    /// past the loaded ones. Throws `ArchiveError`; the workspace is unchanged.
    public mutating func openDocument(
        _ package: PhotoPackage, name: String, archive: any DocumentArchiving, codec: any PhotoImageCodec
    ) throws {
        try openDocument(archive.decode(package, codec: codec), name: name)
    }

    /// Opens an already decoded document, named `name`, as
    /// `openDocument(_:name:archive:codec:)` does, so the window can decode
    /// its PNGs off the main actor first. Throws `ArchiveError.damaged`; the
    /// workspace is unchanged.
    public mutating func openDocument(_ document: PhotoDocumentSnapshot, name: String) throws {
        let stack = try Self.stack(of: document)
        let base = try stack.pixels.values.first
            ?? Self.tiles(width: document.canvas.width, height: document.canvas.height, what: "the canvas")
        start(with: base, name: name)
        layers = stack.layers
        pixels = stack.pixels
        masks = stack.masks
        selectedLayerID = stack.selectedLayerID
        adjustments = document.adjustments
        fileKind = .document
        reserveLayerIDs(after: layers.compactMap { $0.id.hasPrefix("layer-") ? Int($0.id.dropFirst(6)) : nil }.max() ?? 0)
        savedStepID = currentStepID
        touch(.all)
    }

    /// The layer stack `document` describes, its pixels in tiles. Throws
    /// `ArchiveError.damaged` for a document with no layers, a repeated id, a
    /// pixel layer or mask without its image, or an image of the wrong size.
    private static func stack(of document: PhotoDocumentSnapshot) throws -> PhotoStack {
        guard !document.layers.isEmpty else { throw ArchiveError.damaged("the document has no layers") }
        guard Set(document.layers.map(\.id)).count == document.layers.count else {
            throw ArchiveError.damaged("two layers share an id")
        }
        var pixels: [PhotoLayer.ID: TiledPixels] = [:], masks: [PhotoLayer.ID: TiledPixels] = [:]
        var layers = document.layers
        for (i, layer) in layers.enumerated() {
            if layer.kind == .pixels {
                guard let image = document.pixels[layer.id] else { throw ArchiveError.damaged("\(layer.name) has no pixels") }
                pixels[layer.id] = try tiles(image, what: layer.name)
            }
            if let image = document.masks[layer.id] {
                let mask = try tiles(image, what: "\(layer.name)'s mask")
                if let own = pixels[layer.id], own.width != mask.width || own.height != mask.height {
                    throw ArchiveError.damaged("\(layer.name)'s mask is the wrong size")
                }
                masks[layer.id] = mask
                layers[i].hasMask = true
            } else if layer.hasMask {
                throw ArchiveError.damaged("\(layer.name)'s mask is missing")
            }
        }
        let selected = document.selectedLayerID.flatMap { id in layers.contains { $0.id == id } ? id : nil }
        return PhotoStack(
            canvas: document.canvas, layers: layers, pixels: pixels, masks: masks,
            selectedLayerID: selected ?? layers.first?.id, selection: nil)
    }

    private static func tiles(_ image: DecodedImage, what: String) throws -> TiledPixels {
        do {
            return try TiledPixels(rgba8: image.rgba8, width: image.width, height: image.height)
        } catch {
            throw ArchiveError.damaged("\(what) has bad pixels")
        }
    }

    private static func tiles(width: Int, height: Int, what: String) throws -> TiledPixels {
        do {
            return try TiledPixels(width: width, height: height)
        } catch {
            throw ArchiveError.damaged("\(what) has a bad size")
        }
    }
}

extension PhotoServices {
    /// These services with autosaves kept in `directory` (the window's
    /// `-PhotoRecoveryDir`) instead of the default recovery folder.
    public func recovering(in directory: URL) -> PhotoServices {
        var services = self
        services.recovery = LiveDocuments.recovery(directory: directory)
        return services
    }
}
