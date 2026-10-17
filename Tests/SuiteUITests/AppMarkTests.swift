// AppMarkTests.swift: AppMark (AppMark.swift) draws every SuiteApp, nil
// included, in every style at 16 and 1024 pt, inside its frame and never
// empty; the -small groups take over at 32 pt and under for .icon and .glyph,
// never for .line, whose stroke has a one-point floor; and what AppMark draws is what Bundle/Icons holds: its .icon
// at 128 and at 32 matches <App>-128.png and <App>-32.png, the rsvg renders of
// the same SVG, within antialiasing. So AppMarkArt.swift and the PNGs can't
// drift apart. macOS only.
import AppKit
import SuiteModel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct AppMarkTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    /// The view at `side` x `side` pixels as straight RGBA bytes, row by row.
    static func pixels(_ view: some View, side: Int) throws -> [UInt8] {
        let renderer = ImageRenderer(content: view.frame(width: CGFloat(side), height: CGFloat(side)))
        renderer.scale = 1
        return try rgba(#require(renderer.cgImage, "no image"), side: side)
    }

    static func rgba(_ image: CGImage, side: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        #expect(drawn)
        return bytes
    }

    static func png(_ name: String, side: Int) throws -> [UInt8] {
        let url = root.appendingPathComponent("Bundle/Icons/\(name)")
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil), "can't read \(name)")
        return try rgba(#require(CGImageSourceCreateImageAtIndex(source, 0, nil)), side: side)
    }

    /// The pixels whose alpha is over a quarter, as a box: (minX, minY, maxX, maxY).
    static func inked(_ bytes: [UInt8], side: Int) -> (Int, Int, Int, Int)? {
        var box: (Int, Int, Int, Int)?
        for y in 0..<side {
            for x in 0..<side where bytes[(y * side + x) * 4 + 3] > 64 {
                let b = box ?? (x, y, x, y)
                box = (min(b.0, x), min(b.1, y), max(b.2, x), max(b.3, y))
            }
        }
        return box
    }

    static let marks: [SuiteApp?] = [nil] + SuiteApp.allCases

    @Test func everyAppHasArt() {
        for app in SuiteApp.allCases {
            #expect(AppMarkArt.all[app.rawValue] != nil, "\(app)")
        }
        #expect(AppMarkArt.all.count == SuiteApp.allCases.count)
    }

    @Test(arguments: [16, 1024]) func everyMarkDrawsInsideItsFrame(_ side: Int) throws {
        for app in Self.marks {
            for style in AppMark.Style.allCases {
                let bytes = try Self.pixels(AppMark(app: app, style: style).foregroundStyle(.black), side: side)
                let box = try #require(Self.inked(bytes, side: side), "\(String(describing: app)) \(style) drew nothing at \(side)")
                #expect(box.0 >= 0 && box.1 >= 0 && box.2 < side && box.3 < side)
                if style == .icon {
                    // The tile sits on the macOS icon grid: inset 100 of 1024 on each side.
                    let inset = Double(side) * 100 / 1024
                    #expect(Double(box.0) >= inset - 1 && Double(box.2) <= Double(side) - inset + 1,
                            "\(String(describing: app)) icon leaves the grid at \(side)")
                }
            }
        }
    }

    @Test func theSmallGroupsDrawAt32AndUnder() {
        #expect(AppMark.drawsSmall(.icon, side: 16))
        #expect(AppMark.drawsSmall(.icon, side: 32))
        #expect(!AppMark.drawsSmall(.icon, side: 33))
        #expect(!AppMark.drawsSmall(.icon, side: 1024))
        // A .glyph frame is the glyph's 664-unit box: 20 pt stands for a 30.8 pt icon.
        #expect(AppMark.drawsSmall(.glyph, side: 20))
        #expect(!AppMark.drawsSmall(.glyph, side: 22))
        #expect(!AppMark.drawsSmall(.line, side: 16))
        let art = AppMarkArt.all["flare"]
        #expect(art.map { AppMark.elements($0, .icon, side: 16).count } == art.map { $0.tile.count + $0.tileSmall.count + $0.glyphSmall.count })
        #expect(art.map { AppMark.elements($0, .line, side: 16).count } == art.map { $0.line.count })
    }

    /// A .line stroke is never thinner than `AppMark.minLineWidth` points, so a
    /// chip-sized mark (about 10 pt) holds up beside its label; at the
    /// switcher's 22 pt the art's own width (1.6 of 24 units, 1.47 pt) stands.
    @Test func aLineStrokeHasAFloorOfOnePoint() throws {
        let box = AppMark.box(.line).width
        let art = 37.33, side: CGFloat = 10
        #expect(AppMark.lineWidth(art, .line, side: side) * side / box >= AppMark.minLineWidth - 0.001)
        #expect(AppMark.lineWidth(art, .line, side: SuiteSize.switcherIcon) == art)
        // The coloured forms keep the art's widths at every size.
        #expect(AppMark.lineWidth(art, .glyph, side: side) == art)
        #expect(AppMark.lineWidth(art, .icon, side: side) == art)
    }

    /// Mean absolute difference per channel, 0 to 255, between AppMark's .icon and the rsvg PNG.
    @Test(arguments: [128, 32]) func theIconIsThePNG(_ side: Int) throws {
        for app in [SuiteApp.launcher] + SuiteApp.apps {
            let name = app == .launcher ? "AfterGlow" : app.displayName
            let drawn = try Self.pixels(AppMark(app: app, style: .icon), side: side)
            let rendered = try Self.png("\(name)-\(side).png", side: side)
            let total = zip(drawn, rendered).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
            let mean = Double(total) / Double(drawn.count)
            #expect(mean < 3, "\(name) at \(side): AppMark differs from Bundle/Icons by \(mean) per channel")
        }
    }
}
