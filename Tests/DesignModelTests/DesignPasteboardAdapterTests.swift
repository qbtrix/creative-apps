// DesignPasteboardAdapterTests.swift: clipboard-interop CB-5, turned on by CB-6 (packet
// docs/blueprints/suiteui/features/clipboard-interop.md, slice CB-design). Design's Copy of a red
// 200 x 100 rectangle offers its own layers, an SVG and a PNG of the selection's bounds at 2x
// (400 x 200 px, centre pixel red), in the coder's order; Paste of a 300 x 200 px PNG adds one layer
// 300 x 200 pt centred in the view, one undo step. Photo, offered that copy, takes the PNG.
//
// Disabled until CB-6: `DesignPasteboardAdapter` doesn't exist yet, so the two calls below go
// through `Seam`, which CB-6 points at the adapter (and deletes) when it turns these on. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteModel
import Testing

/// The adapter's two calls as CB-6 builds them. Until then a copy offers nothing and a paste does nothing.
private enum Seam {
    /// CB-6: `DesignPasteboardAdapter().copy(workspace)`, the selection's representations, richest first.
    static func copy(_ workspace: DesignWorkspace) throws -> [TypedData] { [] }
    /// CB-6: `try DesignPasteboardAdapter().paste(item, into: &workspace, centredOn: centre)`.
    static func paste(_ item: SuiteClipItem, into workspace: inout DesignWorkspace, centredOn centre: DesignPoint) throws {}
}

/// One page of 1440 x 1024 holding the red rectangle Red (node-1) at (100, 100), 200 x 100, selected.
private func redFile() throws -> DesignWorkspace {
    let red = DesignNode(id: "node-1", name: "Red", kind: .rectangle, frame: rc(100, 100, 200, 100), fill: DesignColor(255, 0, 0))
    let page = DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: [red])
    var workspace = DesignWorkspace()
    try workspace.open(LiveFiling().encode(DesignDocument(pages: [page])))
    workspace.useServices(.live)
    workspace.selectItem("node-1")
    return workspace
}

/// A PNG's width and height from its IHDR chunk, nil when `data` isn't a PNG.
private func pngSize(_ data: Data) -> (width: Int, height: Int)? {
    let bytes = [UInt8](data)
    let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    guard bytes.count >= 24, Array(bytes[0..<8]) == signature, Array(bytes[12..<16]) == Array("IHDR".utf8) else { return nil }
    let int = { (at: Int) in bytes[at..<(at + 4)].reduce(0) { $0 << 8 | Int($1) } }
    return (int(16), int(20))
}

/// A 300 x 200 px PNG header (signature and IHDR): enough for a paste to read its size.
private let png300x200 = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13] + Array("IHDR".utf8)
    + [0, 0, 0x01, 0x2C, 0, 0, 0, 0xC8, 8, 6, 0, 0, 0] + [0, 0, 0, 0])

@Suite struct DesignPasteboardAdapterTests {
    /// The copy offers Design's own layers, then an SVG, then a PNG, and nothing else.
    @Test(.disabled("waits on CB-6")) func copyOffersOwnLayersSvgAndPng() throws {
        let offered = try Seam.copy(redFile())
        #expect(offered.map(\.type) == [.designLayers, .svg, .png])
        let own = try #require(offered.first { $0.type == .designLayers })
        #expect(own.data == (try redFile().copySelection()), "the own bytes are Copy's, so Design pastes them back as layers")
    }

    /// Mutation `.pngAtTwoX`: the PNG is the selection's bounds at 2x, never the whole page or 1x.
    @Test(.disabled("waits on CB-6")) func pngIsTheSelectionAtTwoX() throws {
        let png = try #require(try Seam.copy(redFile()).first { $0.type == .png })
        let size = try #require(pngSize(png.data), "the PNG bytes aren't a PNG")
        #expect(size.width == 400 && size.height == 200, "the PNG is \(size.width) x \(size.height), not 400 x 200")
    }

    /// The SVG is one red rect the size of the selection.
    @Test(.disabled("waits on CB-6")) func svgIsTheRedRect() throws {
        let svg = try #require(try Seam.copy(redFile()).first { $0.type == .svg })
        let text = String(decoding: svg.data, as: UTF8.self)
        #expect(text.contains("<svg") && text.components(separatedBy: "<rect").count == 2, "not one rect: \(text)")
        #expect(text.contains(#"width="200""#) && text.contains(#"height="100""#))
        #expect(text.uppercased().contains("#FF0000") || text.contains("rgb(255,0,0)") || text.contains("fill=\"red\""))
    }

    /// RJ-X72's trap: Photo, offered Design's copy, takes the PNG, so its Paste is on.
    @Test(.disabled("waits on CB-6")) func photoTakesThePng() throws {
        let coder = SuitePasteboardCoding()
        let offered = try Seam.copy(redFile())
        #expect(coder.pasteRefusal(for: offered, in: .photo) == nil, "Photo's Paste is off for Design's copy")
        guard case .image(let png, _, _)? = coder.bestItem(from: offered, for: .photo) else {
            Issue.record("Photo took no image from Design's copy"); return
        }
        #expect(pngSize(png).map { [$0.width, $0.height] } == [400, 200])
    }

    /// Mutation `.pasteCentres`: a pasted 300 x 200 PNG is one new layer, 300 x 200 pt, centred on the view, one step.
    @Test(.disabled("waits on CB-6")) func pastedPngIsOneLayerCentredInTheView() throws {
        var workspace = try redFile()
        let before = workspace.selectedPage?.nodes.count ?? 0
        try Seam.paste(.image(png: png300x200, pixelWidth: 300, pixelHeight: 200), into: &workspace, centredOn: pt(720, 512))
        let nodes = workspace.selectedPage?.nodes ?? []
        #expect(nodes.count == before + 1, "the paste added \(nodes.count - before) layers, not 1")
        let placed = try #require(nodes.last)
        #expect(placed.frame == rc(570, 412, 300, 200), "the picture sits at \(placed.frame), not centred on (720, 512)")
        #expect(workspace.selectedNodeIDs == [placed.id], "the pasted picture is selected")
        workspace.undo()
        #expect(workspace.selectedPage?.nodes.count == before, "one undo takes the paste back")
    }

    /// Plain text on the pasteboard: Design's Paste is off and says why in the coder's sentence.
    @Test(.disabled("waits on CB-6")) func textAloneIsRefused() {
        let text = [TypedData(type: .plainText, data: Data("hello".utf8))]
        #expect(SuitePasteboardCoding().pasteRefusal(for: text, in: .design) != nil)
    }
}
