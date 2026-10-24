// PhotoPasteboardAdapterTests.swift (clipboard-interop CB-13, packet docs/blueprints/suiteui/features/clipboard-interop.md,
// slice CB-photo): the oracle for Photo's side of the shared pasteboard, written from what PhotoApp's PhotoPasteboard
// does today. Copy offers the pixels as PNG, then TIFF; neither carries the source rect or any source metadata
// (RJ-X05). Paste takes any image the coder offers (PNG, TIFF, JPEG, HEIC) with no source rect, and an SVG drawn to
// fit the open canvas. Text alone is refused with the coder's sentence. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import PhotoModel
import SuiteModel
import Testing

/// A 4 x 3 opaque image, each pixel its own colour, so a round trip can't pass by luck.
private let image4x3: DecodedImage = {
    var bytes = [UInt8]()
    for i in 0..<12 { bytes += [UInt8(i * 20), UInt8(255 - i * 20), UInt8(i * 7), 255] }
    return DecodedImage(rgba8: bytes, width: 4, height: 3)
}()

/// A codec that decodes any bytes to `image4x3` and records what it was given: another app's TIFF, JPEG or HEIC.
private final class AnyImageCodec: PhotoImageCodec, @unchecked Sendable {
    var decoded: [Data] = []
    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage { decoded.append(data); return image4x3 }
    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data { Data() }
}

/// A rasterizer that records the size it was asked for and draws a blank image of that size.
private final class SizeRecorder: @unchecked Sendable {
    var asked: [(width: Int, height: Int)] = []
    func rasterize(_ svg: String, _ width: Int, _ height: Int) throws -> DecodedImage {
        asked.append((width, height))
        return DecodedImage(rgba8: [UInt8](repeating: 0, count: width * height * 4), width: width, height: height)
    }
}

/// The chunk types of a PNG, in order.
private func pngChunks(_ data: Data) -> [String] {
    let b = [UInt8](data)
    var at = 8, out: [String] = []
    while at + 12 <= b.count {
        let length = b[at..<(at + 4)].reduce(0) { $0 << 8 | Int($1) }
        out.append(String(decoding: b[(at + 4)..<(at + 8)], as: UTF8.self))
        at += 12 + length
    }
    return out
}

private let tiffMarker = Data("II*\0tiff".utf8)

private func svg(_ attributes: String) -> TypedData {
    TypedData(type: .svg, data: Data("<?xml version=\"1.0\"?><svg xmlns=\"http://www.w3.org/2000/svg\" \(attributes)><rect width=\"10\" height=\"10\"/></svg>".utf8))
}

@Suite struct PhotoPasteboardAdapterTests {
    /// Mutation `.writesPngAndTiff`: Copy offers PNG first, then TIFF, as PhotoPasteboard writes them today.
    @Test func writesPngAndTiff() throws {
        let adapter = PhotoPasteboardAdapter(tiff: { _ in tiffMarker })
        let offered = adapter.copy(ClipboardImage(image: image4x3, source: PixelRect(x: 4, y: 5, width: 4, height: 3)))
        #expect(offered.map(\.type) == [.png, .tiff], "Copy offers \(offered.map(\.type.rawValue))")
        #expect(offered.last?.data == tiffMarker)
        let png = try #require(offered.first)
        #expect(try CoreRasterImageCodec().decode(png.data, longestSide: nil) == image4x3, "the PNG isn't the copied pixels")
        for app in [SuiteApp.design, .flare, .halo, .photo] {
            #expect(SuitePasteboardCoding().pasteRefusal(for: offered, in: app) == nil, "\(app) can't paste Photo's copy")
        }
    }

    /// Without a TIFF encoder (Linux, the CLI) Copy still offers the PNG; the shell's bridge adds TIFF beside it.
    @Test func copiesPngAloneWithoutATiffEncoder() {
        let offered = PhotoPasteboardAdapter().copy(ClipboardImage(image: image4x3, source: nil))
        #expect(offered.map(\.type) == [.png])
        let failing = PhotoPasteboardAdapter(tiff: { _ in throw SuiteError.notAvailable("no TIFF") })
        #expect(failing.copy(ClipboardImage(image: image4x3, source: nil)).map(\.type) == [.png])
    }

    /// RJ-X05: the copy carries pixels only: no text, Exif or time chunks, nothing naming where it came from.
    @Test func copyCarriesNoSourceMetadata() throws {
        let png = try #require(PhotoPasteboardAdapter().copy(ClipboardImage(image: image4x3, source: PixelRect(x: 4, y: 5, width: 4, height: 3))).first)
        let chunks = pngChunks(png.data)
        #expect(chunks.first == "IHDR" && chunks.last == "IEND")
        for metadata in ["eXIf", "tEXt", "iTXt", "zTXt", "tIME"] {
            #expect(!chunks.contains(metadata), "the copy's PNG has a \(metadata) chunk")
        }
    }

    /// A PNG from another app pastes as its pixels with no source rect: where it lands is the model's call.
    @Test func pastesAPng() throws {
        let png = try CoreRasterImageCodec().encode(image4x3, as: .png, quality: 1)
        let pasted = try PhotoPasteboardAdapter().paste([TypedData(type: .png, data: png)], canvas: nil)
        #expect(pasted == ClipboardImage(image: image4x3, source: nil))
    }

    /// Any image type the coder offers is decoded by the codec: TIFF, JPEG and HEIC as well as PNG.
    @Test func pastesAnyImage() throws {
        for type in [SuiteTypeID.tiff, .jpeg, .heic] {
            let codec = AnyImageCodec()
            let bytes = Data(type.rawValue.utf8)
            let pasted = try PhotoPasteboardAdapter(codec: codec).paste([TypedData(type: type, data: bytes)], canvas: nil)
            #expect(pasted.image == image4x3 && pasted.source == nil)
            #expect(codec.decoded == [bytes], "\(type.rawValue) wasn't decoded")
        }
    }

    /// Mutation `.svgFitsCanvas`: a 100 x 50 SVG pastes drawn at 800 x 400 on an 800 x 600 canvas, never its own size.
    @Test func svgFitsCanvas() throws {
        let recorder = SizeRecorder()
        let adapter = PhotoPasteboardAdapter(rasterize: recorder.rasterize)
        let pasted = try adapter.paste([svg("width=\"100px\" height=\"50\"")], canvas: CanvasSize(width: 800, height: 600))
        #expect(recorder.asked.map { [$0.width, $0.height] } == [[800, 400]])
        #expect(pasted.image.width == 800 && pasted.image.height == 400 && pasted.source == nil)
        _ = try adapter.paste([svg("viewBox=\"0 0 40 80\"")], canvas: CanvasSize(width: 800, height: 600))
        #expect(recorder.asked.last.map { [$0.width, $0.height] } == [300, 600], "the viewBox's 1:2 doesn't fit 800 x 600")
    }

    /// With no image open an SVG keeps its own size; with no size of its own it fills the canvas.
    @Test func svgSizeWithoutCanvasOrOwnSize() throws {
        let recorder = SizeRecorder()
        let adapter = PhotoPasteboardAdapter(rasterize: recorder.rasterize)
        _ = try adapter.paste([svg("width=\"100\" height=\"50\"")], canvas: nil)
        _ = try adapter.paste([svg("")], canvas: CanvasSize(width: 320, height: 200))
        #expect(recorder.asked.map { [$0.width, $0.height] } == [[100, 50], [320, 200]])
    }

    /// An image beats an SVG for Photo: it places pixels, so the SVG is its last picture.
    @Test func imageBeatsSvg() throws {
        let png = try CoreRasterImageCodec().encode(image4x3, as: .png, quality: 1)
        let recorder = SizeRecorder()
        let pasted = try PhotoPasteboardAdapter(rasterize: recorder.rasterize)
            .paste([svg("width=\"10\" height=\"10\""), TypedData(type: .png, data: png)], canvas: nil)
        #expect(pasted.image == image4x3 && recorder.asked.isEmpty)
    }

    /// Text alone, an empty pasteboard and an SVG with no rasterizer are refused with a sentence the window shows.
    @Test func refusals() {
        let adapter = PhotoPasteboardAdapter()
        let text = [TypedData(type: .plainText, data: Data("hello".utf8))]
        #expect(adapter.pasteRefusal(text) == .cannotPaste(app: .photo, kind: "text"))
        #expect(throws: SuiteError.cannotPaste(app: .photo, kind: "text")) { try adapter.paste(text, canvas: nil) }
        #expect(adapter.pasteRefusal([]) == .nothingToPaste)
        #expect(throws: SuiteError.nothingToPaste) { try adapter.paste([], canvas: nil) }
        #expect(adapter.pasteRefusal([svg("")]) == nil)
        #expect(throws: SuiteError.self) { try adapter.paste([svg("width=\"10\" height=\"10\"")], canvas: nil) }
    }
}
