// PhotoPasteboardTests.swift: PhotoPasteboard round-trips 8-bit straight RGBA
// through a pasteboard, reads an image offered only as TIFF, and finds nothing
// on an empty pasteboard (photo-edit E-6). Each test uses its own private named
// pasteboard, released after, so the general pasteboard is never touched.
// macOS only.
import AppKit
import CoreRaster
import Foundation
import PhotoModel
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoPasteboardTests {
    /// Opaque pixels of different colors and one fully transparent one (all
    /// zero), which survive the premultiplied decode unchanged.
    private let image = DecodedImage(
        rgba8: [
            255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
            12, 34, 56, 255, 200, 150, 100, 255, 0, 0, 0, 0,
        ], width: 3, height: 2)

    private func withPasteboard(_ body: (NSPasteboard) -> Void) {
        let pasteboard = NSPasteboard(name: .init("photo-edit-test-\(UUID().uuidString)"))
        body(pasteboard)
        pasteboard.releaseGlobally()
    }

    @Test func writeThenReadGivesTheSameBytes() {
        withPasteboard { pasteboard in
            PhotoPasteboard.write(ClipboardImage(image: image, source: PixelRect(x: 4, y: 5, width: 3, height: 2)), to: pasteboard)
            #expect(PhotoPasteboard.hasImage(pasteboard))
            let read = PhotoPasteboard.read(from: pasteboard)
            #expect(read == ClipboardImage(image: image, source: nil))
        }
    }

    @Test func aTIFFOnlyPasteboardReads() {
        withPasteboard { written in
            PhotoPasteboard.write(ClipboardImage(image: image, source: nil), to: written)
            let tiff = written.data(forType: .tiff)
            #expect(tiff != nil)
            withPasteboard { tiffOnly in
                _ = tiffOnly.declareTypes([.tiff], owner: nil)
                _ = tiffOnly.setData(tiff, forType: .tiff)
                #expect(PhotoPasteboard.hasImage(tiffOnly))
                #expect(PhotoPasteboard.read(from: tiffOnly)?.image == image)
            }
        }
    }

    @Test func anEmptyPasteboardHasNoImage() {
        withPasteboard { pasteboard in
            pasteboard.clearContents()
            #expect(!PhotoPasteboard.hasImage(pasteboard))
            #expect(PhotoPasteboard.read(from: pasteboard) == nil)
        }
    }
}
