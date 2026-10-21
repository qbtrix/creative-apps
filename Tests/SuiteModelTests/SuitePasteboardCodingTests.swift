// SuitePasteboardCodingTests.swift (clipboard-interop CB-2, turned on by CB-3): the live coder lists an item's
// representations richest first (own layers, SVG, PNG, TIFF, text), gives each app the best item it takes from
// what another app copied, and says why Paste is off when nothing fits.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct SuitePasteboardCodingTests {
    let coder = SuitePasteboardCoding()
    let layers = Data(##"{"layers":[{"kind":"rect","fill":"#FF0000"}]}"##.utf8)
    let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100" fill="red"/></svg>"#
    let pngBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    let tiff = SuiteTypeID(rawValue: "public.tiff")

    /// What Design's Copy of a red rectangle offers: its own layers, an SVG and a PNG, in the coder's order.
    var designCopy: [TypedData] {
        [.appLayers(.designLayers, layers), .vector(svg: svg, name: "Rectangle"), .image(png: pngBytes, pixelWidth: 400, pixelHeight: 200)]
            .flatMap(coder.representations(of:))
    }

    /// Mutation `.ownTypeFirst`: an app's own layer bytes come before every picture of them.
    @Test(.disabled("waits on CB-3"))
    func ownLayersComeFirstThenSvgThenPng() {
        #expect(coder.representations(of: .appLayers(.designLayers, layers)) == [TypedData(type: .designLayers, data: layers)])
        #expect(designCopy.map(\.type) == [.designLayers, .svg, .png])
        let shuffled = [designCopy[2], designCopy[0], designCopy[1]]
        #expect(coder.bestItem(from: shuffled, for: .design) == .appLayers(.designLayers, layers))
    }

    /// A Design copy pasted back into Design gives its own layers, not a picture of them.
    @Test(.disabled("waits on CB-3"))
    func designTakesItsOwnLayers() {
        #expect(coder.bestItem(from: designCopy, for: .design) == .appLayers(.designLayers, layers))
        #expect(coder.pasteRefusal(for: designCopy, in: .design) == nil)
    }

    /// Mutation `.photoTakesPixels`: Photo is offered Design's layers, SVG and PNG and takes the PNG.
    @Test(.disabled("waits on CB-3"))
    func photoTakesThePngOfADesignCopy() throws {
        let item = try #require(coder.bestItem(from: designCopy, for: .photo))
        guard case .image(let png, _, _) = item else { Issue.record("Photo took \(item), not the PNG"); return }
        #expect(png == pngBytes)
        #expect(coder.pasteRefusal(for: designCopy, in: .photo) == nil)
    }

    /// Flare is offered an SVG from another app and takes it as vector art.
    @Test(.disabled("waits on CB-3"))
    func flareTakesSvgAsVector() throws {
        let offered = [TypedData(type: .svg, data: Data(svg.utf8)), TypedData(type: .png, data: pngBytes)]
        let item = try #require(coder.bestItem(from: offered, for: .flare))
        guard case .vector(let text, _) = item else { Issue.record("Flare took \(item), not the SVG"); return }
        #expect(text == svg)
    }

    /// Another app's own layers are not this app's: Flare skips Design's layers and takes the SVG beside them.
    @Test(.disabled("waits on CB-3"))
    func anotherAppsLayersFallBackToTheirPicture() throws {
        let item = try #require(coder.bestItem(from: designCopy, for: .flare))
        guard case .vector = item else { Issue.record("Flare took \(item), not the SVG"); return }
    }

    /// A TIFF alone (a screenshot from another app) pastes into Photo as an image.
    @Test(.disabled("waits on CB-3"))
    func tiffAlonePastesAsAnImage() {
        let offered = [TypedData(type: tiff, data: Data([0x4D, 0x4D, 0x00, 0x2A]))]
        #expect(coder.pasteRefusal(for: offered, in: .photo) == nil)
    }

    /// Mutation `.textRefused`: text alone turns Paste off in Photo, with a sentence that names the text.
    @Test(.disabled("waits on CB-3"))
    func textAloneRefusesPasteWithASentence() throws {
        let offered = [TypedData(type: .plainText, data: Data("hello".utf8))]
        let refusal = try #require(coder.pasteRefusal(for: offered, in: .photo))
        #expect(refusal.message.contains("text"))
        #expect(coder.pasteRefusal(for: [], in: .photo) == .nothingToPaste)
    }
}
