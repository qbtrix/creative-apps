// PhotoPasteboard.swift: pixels to and from the pasteboard for Cut, Copy and
// Paste (photo-edit E-6). Write puts the image on as PNG (through
// ImageIOCodec) and as TIFF (the same PNG re-encoded by ImageIO), so other
// apps find the type they read. Read takes the first image there, PNG first,
// then TIFF, then any other image type ImageIO reads, decoded to 8-bit
// straight RGBA by ImageIOCodec. An image from the pasteboard has no source
// rect: where it lands is the model's call. macOS only.
import AppKit
import Foundation
import ImageIO
import PhotoModel
import UniformTypeIdentifiers

@MainActor
enum PhotoPasteboard {
    /// Writes the image as PNG and TIFF on the general pasteboard.
    static func write(_ image: ClipboardImage, to pasteboard: NSPasteboard = .general) {
        guard let png = try? ImageIOCodec().encode(image.image, as: .png, quality: 1) else { return }
        var types: [NSPasteboard.PasteboardType] = [.png]
        let tiff = tiffData(fromImageData: png)
        if tiff != nil { types.append(.tiff) }
        _ = pasteboard.declareTypes(types, owner: nil)
        _ = pasteboard.setData(png, forType: .png)
        if let tiff { _ = pasteboard.setData(tiff, forType: .tiff) }
    }

    /// The first image on the pasteboard (PNG, TIFF or any type ImageIO reads), decoded; nil if none.
    static func read(from pasteboard: NSPasteboard = .general) -> ClipboardImage? {
        let offered = pasteboard.types ?? []
        let candidates = [NSPasteboard.PasteboardType.png, .tiff] + offered.filter { $0 != .png && $0 != .tiff }
        for type in candidates where offered.contains(type) && isImage(type) {
            guard let data = pasteboard.data(forType: type),
                let decoded = try? ImageIOCodec().decode(data, longestSide: nil)
            else { continue }
            return ClipboardImage(image: decoded, source: nil)
        }
        return nil
    }

    static func hasImage(_ pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.canReadItem(withDataConformingToTypes: [UTType.image.identifier])
    }

    private static func isImage(_ type: NSPasteboard.PasteboardType) -> Bool {
        UTType(type.rawValue)?.conforms(to: .image) ?? false
    }

    /// The first image in `data` re-encoded as TIFF by ImageIO; nil if it can't be.
    private static func tiffData(fromImageData data: Data) -> Data? {
        let output = NSMutableData()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
            let destination = CGImageDestinationCreateWithData(output, UTType.tiff.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}
