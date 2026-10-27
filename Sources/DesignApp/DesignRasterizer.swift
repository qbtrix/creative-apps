// DesignRasterizer.swift: the PNG of one planned export item (design-export DE-8; blueprint
// F6, #418), drawn off the window from the canvas's own painter. It only renders: the Model's
// DesignRaster (exportRaster of a plan item) gives the nodes already moved to the origin on a
// page the item's whole-point size, the plan's pixel size and the scale, and has refused a size
// that is empty or over its max side. Here the artwork page's painted list (DesignPage.painted)
// is drawn by DesignArtwork at zoom 1 through ImageRenderer at that scale, redrawn into an 8-bit
// sRGB bitmap with alpha the plan's pixel size, so nothing painted stays transparent, and written
// as PNG by ImageIO. Nothing here touches a window or the Model's state, so no window body runs
// during a write. A JPEG is the same bitmap flattened on the item's background (the plan's
// `background`: its frame's fill, else white) and written by ImageIO at quality 0.9. A render or
// encode that fails throws a DesignRasterizerError. The PDF (DE-9)
// draws the same artwork view through ImageRenderer.render into one PDF page whose media box is
// the artwork page's size in points, the raster's scale left out: a PDF is vector, in points.
// macOS only.
import CoreGraphics
import DesignModel
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum DesignRasterizerError: Error, Equatable {
    /// ImageRenderer or CoreGraphics made no image.
    case renderFailed
    /// ImageIO could not write the PNG or JPEG.
    case encodeFailed
}

/// PNG, JPEG and PDF of planned items, drawn from DesignArtwork off the window.
enum DesignRasterizer {
    /// `raster`'s artwork painted at its scale into an sRGB PNG with alpha, the plan's pixel size.
    @MainActor
    static func png(_ raster: DesignRaster) throws -> Data {
        let renderer = ImageRenderer(content: artwork(raster))
        renderer.scale = CGFloat(raster.scale)
        renderer.isOpaque = false
        guard let drawn = renderer.cgImage else { throw DesignRasterizerError.renderFailed }
        return try encodePNG(try sRGB(drawn, width: raster.pixelWidth, height: raster.pixelHeight))
    }

    /// `raster`'s artwork at its scale flattened on `background`, an opaque sRGB JPEG the plan's pixel size.
    @MainActor
    static func jpeg(_ raster: DesignRaster, background: DesignColor, quality: Double = 0.9) throws -> Data {
        let renderer = ImageRenderer(content: artwork(raster))
        renderer.scale = CGFloat(raster.scale)
        renderer.isOpaque = false
        guard let drawn = renderer.cgImage else { throw DesignRasterizerError.renderFailed }
        let (width, height) = (raster.pixelWidth, raster.pixelHeight)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw DesignRasterizerError.renderFailed }
        let rgb = [background.red, background.green, background.blue].map { CGFloat($0) / 255 }
        context.setFillColor(CGColor(srgbRed: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(drawn, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let flat = context.makeImage() else { throw DesignRasterizerError.renderFailed }
        return try encode(flat, as: .jpeg, [kCGImageDestinationLossyCompressionQuality: min(max(quality, 0), 1)])
    }

    /// `raster`'s artwork as one PDF page, its media box the artwork page's size in points.
    @MainActor
    static func pdf(_ raster: DesignRaster) throws -> Data {
        var box = CGRect(x: 0, y: 0, width: raster.artwork.frameWidth, height: raster.artwork.frameHeight)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { throw DesignRasterizerError.renderFailed }
        ImageRenderer(content: artwork(raster)).render { _, draw in
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
        }
        context.closePDF()
        guard data.length > 0 else { throw DesignRasterizerError.encodeFailed }
        return data as Data
    }

    /// The canvas's painter over `raster`'s artwork at zoom 1, the artwork page's size, light.
    @MainActor
    private static func artwork(_ raster: DesignRaster) -> some View {
        DesignArtwork(painted: raster.artwork.painted, zoom: 1)
            .frame(width: raster.artwork.frameWidth, height: raster.artwork.frameHeight)
            .environment(\.colorScheme, .light)
    }

    /// `image` drawn into a `width` × `height` 8-bit sRGB bitmap with premultiplied alpha.
    private static func sRGB(_ image: CGImage, width: Int, height: Int) throws -> CGImage {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw DesignRasterizerError.renderFailed }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let out = context.makeImage() else { throw DesignRasterizerError.renderFailed }
        return out
    }

    /// `image` as PNG bytes through ImageIO.
    private static func encodePNG(_ image: CGImage) throws -> Data { try encode(image, as: .png, [:]) }

    /// `image` as `type`'s bytes through ImageIO, with destination `properties`.
    private static func encode(_ image: CGImage, as type: UTType, _ properties: [CFString: Any]) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)
        else { throw DesignRasterizerError.encodeFailed }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw DesignRasterizerError.encodeFailed }
        return data as Data
    }
}
