// PhotoOpenTypesTests.swift: Photo's Open panel offers only what Photo can open (#5081). Its document, plus the
// registry's image types that ImageIOCodec decodes (ImageIO's decoders on this Mac), never a type it can't read.
// Each offered type that ImageIO can also write is written as a 4 x 4 fixture and decoded through ImageIOCodec.
// macOS only.
#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import SuiteUI
import Testing
import UniformTypeIdentifiers

@testable import PhotoApp

@MainActor @Suite struct PhotoOpenTypesTests {
    @Test func openOffersTheDocumentAndTheCommonImages() {
        for ext in ["ora", "png", "jpg", "heic"] {
            #expect(PhotoWindow.openTypes.contains(UTType(filenameExtension: ext)!), "\(ext)")
        }
    }

    @Test func everyOfferedImageTypeHasADecoder() {
        for type in PhotoWindow.openTypes where !PhotoWindow.documentTypes.contains(type) {
            #expect(!ImageIOCodec.decodable([type]).isEmpty, "\(type.identifier) has no ImageIO decoder")
        }
    }

    @Test func aTypeWithNoDecoderIsDropped() {
        let unknown = UTType(filenameExtension: "photo-open-types-test")!
        #expect(ImageIOCodec.decodable([unknown, .png]) == [.png])
    }

    @Test func everyWritableOfferedTypeDecodesAFixture() throws {
        let writable = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16,
                                             space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let image = try #require(context.makeImage())
        var decoded = 0
        for type in PhotoWindow.openTypes where writable.contains(type.identifier) {
            let data = NSMutableData()
            guard let out = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(out, image, nil)
            guard CGImageDestinationFinalize(out) else { continue }
            let pixels = try ImageIOCodec().decode(data as Data, longestSide: nil)
            #expect(pixels.width == 4 && pixels.height == 4, "\(type.identifier)")
            decoded += 1
        }
        #expect(decoded >= 4, "too few fixtures: \(decoded)")
    }
}
#endif
