// PhotoPasteboardTests.swift: Photo's Copy and Paste through SuiteShell's
// PasteboardBridge and photoPasteboardAdapter (clipboard-interop CB-13; ported
// from PhotoPasteboard's tests in CB-15) round-trip 8-bit straight RGBA, read an
// image offered only as TIFF, and find nothing on an empty pasteboard (photo-edit
// E-6). PhotoCopySource gives Photo's own
// copy its source rect back until another write moves the pasteboard on, so
// an in-app paste lands in place (PJ-5). Each test uses its own private named
// pasteboard, released after, so the general pasteboard is never touched.
// macOS only.
import AppKit
import CoreRaster
import Foundation
import PhotoModel
import SuiteShell
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

    /// Photo's writes and reads as the window makes them: the adapter's items through the bridge.
    @MainActor private enum Bridge {
        static func write(_ image: ClipboardImage, to pasteboard: NSPasteboard) {
            PasteboardBridge(pasteboard).write(photoPasteboardAdapter.copy(image))
        }

        static func read(from pasteboard: NSPasteboard) -> ClipboardImage? {
            try? photoPasteboardAdapter.paste(PasteboardBridge(pasteboard).offered(), canvas: nil)
        }

        static func hasImage(_ pasteboard: NSPasteboard) -> Bool {
            photoPasteboardAdapter.pasteRefusal(PasteboardBridge(pasteboard).offered()) == nil
        }
    }

    private func withPasteboard(_ body: (NSPasteboard) -> Void) {
        let pasteboard = NSPasteboard(name: .init("photo-edit-test-\(UUID().uuidString)"))
        body(pasteboard)
        pasteboard.releaseGlobally()
    }

    @Test func writeThenReadGivesTheSameBytes() {
        withPasteboard { pasteboard in
            Bridge.write(ClipboardImage(image: image, source: PixelRect(x: 4, y: 5, width: 3, height: 2)), to: pasteboard)
            #expect(Bridge.hasImage(pasteboard))
            let read = Bridge.read(from: pasteboard)
            #expect(read == ClipboardImage(image: image, source: nil))
        }
    }

    @Test func aTIFFOnlyPasteboardReads() {
        withPasteboard { written in
            Bridge.write(ClipboardImage(image: image, source: nil), to: written)
            let tiff = written.data(forType: .tiff)
            #expect(tiff != nil)
            withPasteboard { tiffOnly in
                _ = tiffOnly.declareTypes([.tiff], owner: nil)
                _ = tiffOnly.setData(tiff, forType: .tiff)
                #expect(Bridge.hasImage(tiffOnly))
                #expect(Bridge.read(from: tiffOnly)?.image == image)
            }
        }
    }

    @Test func photosOwnCopyPastesBackOnItsSourceUntilAnotherWrite() throws {
        try withThrowingPasteboard { pasteboard in
            let copy = ClipboardImage(image: image, source: PixelRect(x: 4, y: 5, width: 3, height: 2))
            PhotoCopySource.write(copy, to: pasteboard)
            let own = try #require(Bridge.read(from: pasteboard))
            #expect(PhotoCopySource.restored(own, from: pasteboard) == copy)

            // Another app writes the same picture: it carries no place, so it pastes centered.
            Bridge.write(ClipboardImage(image: image, source: nil), to: pasteboard)
            let other = try #require(Bridge.read(from: pasteboard))
            #expect(PhotoCopySource.restored(other, from: pasteboard).source == nil)
        }
    }

    private func withThrowingPasteboard(_ body: (NSPasteboard) throws -> Void) throws {
        let pasteboard = NSPasteboard(name: .init("photo-edit-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        try body(pasteboard)
    }

    @Test func anEmptyPasteboardHasNoImage() {
        withPasteboard { pasteboard in
            pasteboard.clearContents()
            #expect(!Bridge.hasImage(pasteboard))
            #expect(Bridge.read(from: pasteboard) == nil)
        }
    }
}
