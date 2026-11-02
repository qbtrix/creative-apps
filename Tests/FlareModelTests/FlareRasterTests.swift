// FlareRasterTests.swift: the plain-Swift PNG rasterizer (FlareRaster) draws fills, masks and mattes, and a symbol's
// frames move, so headless PNG frames show what the stage and the SVG export show (flare-export QB gate #6200).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteModel
import Testing
@testable import FlareModel

private let red = FlareColor(r: 1, g: 0, b: 0, a: 1)

private func rect(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) throws -> FlarePath {
    try PathBuilders.rectangle(in: Rect(minX: x0, minY: y0, maxX: x1, maxY: y1))
}

private func item(_ path: FlarePath, _ color: FlareColor = red) -> StageItem {
    StageItem(address: StageAddress(owner: .scene("s"), layerID: "l", item: .shape(0)), path: path,
              fill: .solid(color), stroke: nil, transform: .identity, opacity: 1)
}

/// The straight RGBA bytes of pixel (x, y).
private func pixel(_ frame: MediaFrame, _ x: Int, _ y: Int) -> [UInt8] {
    let i = (y * frame.width + x) * 4
    return Array(frame.rgba[i..<i + 4])
}

@Test func aFillCoversItsShapeOverTheBackground() throws {
    let list = StageDrawList(width: 10, height: 10, background: .white, items: [item(try rect(0, 0, 5, 10))])
    let frame = try FlareRaster.render(list, width: 10, height: 10, transparent: false)
    #expect(pixel(frame, 2, 5) == [255, 0, 0, 255] && pixel(frame, 8, 5) == [255, 255, 255, 255])
    let clear = try FlareRaster.render(list, width: 10, height: 10, transparent: true)
    #expect(pixel(clear, 8, 5)[3] == 0)
}

@Test func aMaskKeepsOnlyWhatItCovers() throws {
    var square = item(try rect(0, 0, 10, 10))
    square.clips = [ClipMask(path: try rect(0, 0, 5, 10), mode: .add, feather: 0, opacity: 1, inverted: false, depth: 0)]
    let frame = try FlareRaster.render(
        StageDrawList(width: 10, height: 10, background: .white, items: [square]), width: 10, height: 10, transparent: true)
    #expect(pixel(frame, 2, 5) == [255, 0, 0, 255] && pixel(frame, 8, 5)[3] == 0)
    square.clips[0].inverted = true
    let inverted = try FlareRaster.render(
        StageDrawList(width: 10, height: 10, background: .white, items: [square]), width: 10, height: 10, transparent: true)
    #expect(pixel(inverted, 2, 5)[3] == 0 && pixel(inverted, 8, 5) == [255, 0, 0, 255])
}

@Test func aMatteGatesByItsSourcesAlphaOrLuma() throws {
    // A hidden source over the top half: black on the left, white on the right.
    var list = StageDrawList(width: 10, height: 10, background: .white, items: [item(try rect(0, 0, 10, 10))])
    list.matteItems = [item(try rect(0, 0, 5, 5), FlareColor(r: 0, g: 0, b: 0, a: 1)),
                       item(try rect(5, 0, 10, 5), FlareColor(r: 1, g: 1, b: 1, a: 1))]
    list.items[0].matte = MatteLink(sourceItems: 0..<2, inMatteItems: true, kind: .alpha)
    let alpha = try FlareRaster.render(list, width: 10, height: 10, transparent: true)
    #expect(pixel(alpha, 2, 2)[3] == 255 && pixel(alpha, 8, 2)[3] == 255 && pixel(alpha, 5, 8)[3] == 0)
    list.items[0].matte?.kind = .luma
    let luma = try FlareRaster.render(list, width: 10, height: 10, transparent: true)
    #expect(pixel(luma, 2, 2)[3] == 0 && pixel(luma, 8, 2) == [255, 0, 0, 255] && pixel(luma, 5, 8)[3] == 0)
}

@Test func aSymbolInstanceAnimatesAcrossPNGFrames() throws {
    // The same mid frame with the instance playing and held on its first frame: only the symbol differs.
    var held = FlareFixtures.character
    held.scenes[0].layers[2].instances[0].loop = .singleFrame
    let scene = try #require(held.scenes.first)
    let frames = try [FlareFixtures.character, held].map {
        try FlareRaster.render(LiveStage().drawList($0, sceneID: scene.id, frame: scene.durationFrames / 2, editing: nil),
                               width: 275, height: 200, transparent: false).rgba
    }
    #expect(frames[0] != frames[1])
}

@Test func aSizeOutsideTheLimitsThrows() throws {
    let list = StageDrawList(width: 10, height: 10, background: .white, items: [])
    #expect(throws: FlareRasterError.invalidSize) { try FlareRaster.render(list, width: 0, height: 10, transparent: false) }
    #expect(throws: FlareRasterError.invalidSize) {
        try FlareRaster(encode: { _ in Data() }).png(list, scale: 10_000, transparent: false)
    }
}
