// PhotoTestSupport.swift: small fixtures shared by the Photo model tests: an
// open white image, a layer filled with one color, reading a canvas or layer
// pixel, and a fake codec that stores raw bytes. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import PhotoModel

/// An open white `width` x `height` image.
func whiteImage(_ width: Int = 64, _ height: Int = 64) throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: width, height: height)
    return workspace
}

/// Adds a layer filled with one sRGB color over the whole canvas and selects it.
func addFilledLayer(_ workspace: inout PhotoWorkspace, red: UInt8, green: UInt8, blue: UInt8) {
    workspace.addLayer()
    workspace.setToolOption(.color(red: red, green: green, blue: blue))
    workspace.selectAll()
    workspace.fillSelection()
    workspace.deselect()
}

/// The canvas pixel at (x, y), premultiplied linear.
func canvasPixel(_ workspace: PhotoWorkspace, _ x: Int, _ y: Int) throws -> RGBA {
    try workspace.composite().pixel(x: x, y: y)
}

/// The selected layer's own pixel at (x, y).
func layerPixel(_ workspace: PhotoWorkspace, _ x: Int, _ y: Int) throws -> RGBA? {
    try workspace.selectedLayerID.flatMap { workspace.pixels[$0] }?.pixel(x: x, y: y)
}

func point(_ x: Double, _ y: Double) -> Mask.Point { Mask.Point(x: x, y: y) }

/// One drag from `a` to `b`, ended.
func stroke(_ workspace: inout PhotoWorkspace, _ tool: PhotoTool, from a: Mask.Point, to b: Mask.Point) {
    workspace.selectTool(tool)
    workspace.drag(from: a, to: a)
    workspace.drag(from: a, to: b)
    workspace.endDrag()
}

/// A codec whose "file" is 8 bytes of width and height then the raw bytes.
struct RawCodec: PhotoImageCodec {
    struct Unreadable: Error {}

    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage {
        let bytes = [UInt8](data)
        guard bytes.count >= 8 else { throw Unreadable() }
        let width = Int(bytes[0]) << 8 | Int(bytes[1]), height = Int(bytes[2]) << 8 | Int(bytes[3])
        return DecodedImage(rgba8: Array(bytes[8...]), width: width, height: height)
    }

    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
        Data([UInt8(image.width >> 8), UInt8(image.width & 0xFF), UInt8(image.height >> 8), UInt8(image.height & 0xFF),
              format == .png ? 1 : 2, UInt8((quality * 100).rounded()), 0, 0] + image.rgba8)
    }
}
