// HaloPasteboardAdapterTests.swift: clipboard-interop CB-9, turned on by CB-10 (packet
// docs/blueprints/suiteui/features/clipboard-interop.md, slice CB-halo). Halo's Copy Frame at frame 30 of a
// 1920 x 1080 composition offers one PNG of the whole frame at the composition's size, never half; Paste of a
// 160 x 100 px PNG adds one layer whose in point is the playhead (frame 30, never 0), selected, one undo step.
// An SVG pastes as one layer too; plain text alone is refused with the coder's sentence.
//
// Disabled until CB-10: `HaloPasteboardAdapter` doesn't exist yet, so the two calls below go through `Seam`,
// which CB-10 points at the adapter (and deletes) when it turns these on. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import HaloModel
import SuiteModel
import Testing

/// The adapter's two calls as CB-10 builds them. Until then Copy Frame offers nothing and a paste does nothing.
private enum Seam {
    /// CB-10: `try HaloPasteboardAdapter().copyFrame(project)`, the frame at the playhead, richest first.
    static func copyFrame(_ project: HaloProject) throws -> [TypedData] { [] }
    /// CB-10: `try HaloPasteboardAdapter().paste(item, into: &project)`, a placed image layer at the playhead.
    static func paste(_ item: SuiteClipItem, into project: inout HaloProject) throws {}
}

/// A new 1920 x 1080, 30 fps, 10 s composition with its playhead at frame 30.
private func compAtFrame30() throws -> HaloProject {
    var project = HaloProject()
    let made = project.newComposition(CompositionSettings(name: "Comp 1"))
    #expect(made, "no composition was made")
    project.scrub(to: 30)
    #expect(project.selectedComposition?.playheadFrame == 30)
    return project
}

/// A PNG's width and height from its IHDR chunk, nil when `data` isn't a PNG.
private func pngSize(_ data: Data) -> (width: Int, height: Int)? {
    let bytes = [UInt8](data)
    let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    guard bytes.count >= 24, Array(bytes[0..<8]) == signature, Array(bytes[12..<16]) == Array("IHDR".utf8) else { return nil }
    let int = { (at: Int) in bytes[at..<(at + 4)].reduce(0) { $0 << 8 | Int($1) } }
    return (int(16), int(20))
}

/// A 160 x 100 px PNG header (signature and IHDR): enough for a paste to read its size. RJ-X73's screenshot size.
private let png160x100 = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13] + Array("IHDR".utf8)
    + [0, 0, 0, 0xA0, 0, 0, 0, 0x64, 8, 6, 0, 0, 0] + [0, 0, 0, 0])

@Suite struct HaloPasteboardAdapterTests {
    /// Copy Frame offers the frame as a PNG, and Photo, Design and Flare can each take it.
    @Test(.disabled("waits on CB-10")) func copyFrameOffersAPng() throws {
        let offered = try Seam.copyFrame(compAtFrame30())
        #expect(offered.map(\.type) == [.png], "Copy Frame offers \(offered.map(\.type.rawValue)), not one PNG")
        for app in [SuiteApp.photo, .design, .flare] {
            #expect(SuitePasteboardCoding().pasteRefusal(for: offered, in: app) == nil, "\(app)'s Paste is off for Halo's frame")
        }
    }

    /// Mutation `.frameFullSize`: the PNG is the whole composition at 1x, 1920 x 1080, never the preview's half size.
    @Test(.disabled("waits on CB-10")) func copyFrameIsTheCompositionsSize() throws {
        let png = try #require(try Seam.copyFrame(compAtFrame30()).first { $0.type == .png })
        let size = try #require(pngSize(png.data), "the frame bytes aren't a PNG")
        #expect(size.width == 1920 && size.height == 1080, "the frame is \(size.width) x \(size.height), not 1920 x 1080")
    }

    /// Mutation `.pasteAtPlayhead`: a pasted PNG is one new layer starting at frame 30, selected, one undo step.
    @Test(.disabled("waits on CB-10")) func pastedPngIsOneLayerAtThePlayhead() throws {
        var project = try compAtFrame30()
        let before = project.selectedComposition?.layers.count ?? 0
        try Seam.paste(.image(png: png160x100, pixelWidth: 160, pixelHeight: 100), into: &project)
        let layers = project.selectedComposition?.layers ?? []
        #expect(layers.count == before + 1, "the paste added \(layers.count - before) layers, not 1")
        let placed = try #require(project.selectedLayer, "the pasted layer isn't selected")
        #expect(placed.inFrame == 30, "the pasted layer starts at \(placed.inFrame), not the playhead (30)")
        #expect(placed.rect == HaloLayerRect(x: 880, y: 490, width: 160, height: 100), "not 160 x 100 centred: \(String(describing: placed.rect))")
        #expect(project.undoTitle == "Undo Paste")
        project.undo()
        #expect(project.selectedComposition?.layers.count == before, "one undo takes the paste back")
    }

    /// An SVG on the pasteboard pastes as one layer at the playhead too.
    @Test(.disabled("waits on CB-10")) func pastedSvgIsOneLayerAtThePlayhead() throws {
        var project = try compAtFrame30()
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="80" height="40"><rect width="80" height="40" fill="red"/></svg>"#
        try Seam.paste(.vector(svg: svg, name: "Logo"), into: &project)
        #expect(project.selectedComposition?.layers.count == 1, "an SVG paste didn't add one layer")
        #expect(project.selectedLayer?.inFrame == 30)
    }

    /// Plain text on the pasteboard: Halo's Paste is off and says why in the coder's sentence.
    @Test(.disabled("waits on CB-10")) func textAloneIsRefused() {
        let text = [TypedData(type: .plainText, data: Data("hello".utf8))]
        #expect(SuitePasteboardCoding().pasteRefusal(for: text, in: .halo) != nil)
    }
}
