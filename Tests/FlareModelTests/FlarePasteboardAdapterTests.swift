// FlarePasteboardAdapterTests.swift: clipboard-interop CB-7, turned on by CB-8 (packet
// docs/blueprints/suiteui/features/clipboard-interop.md, slice CB-flare). On `-FlareSample bounce` with Ball
// picked and the playhead on frame 12, Copy offers Flare's own layers, an SVG frame and a PNG drawn at the
// playhead at 1x, in the coder's order; the own bytes are Edit > Copy's. Paste of an SVG adds its groups as
// layers through svg-place's place path, as one undo step, and the coder hands Flare that SVG as vectors.
//
// The SVG-to-layers test waits on svg-place PF-5 (Flare's place path); until then `pastedSvgRunsThePlacePath`
// proves the SVG reaches it as vectors. The PNG is made by `Echo`, a rasterizer whose bytes spell out the draw
// list and scale it was given, so the frame drawn can be read on Linux.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import SuiteKernel
import SuiteModel
import Testing

/// A rasterizer whose "PNG" is the list's description and the scale, so a test can tell which frame it drew.
private struct Echo: FrameRasterizing {
    func png(_ list: StageDrawList, scale: Double, transparent: Bool) throws -> Data {
        Data("scale \(scale) \(list)".utf8)
    }
}

/// `-FlareSample bounce` (Background locked, Shadow, Ball) with Ball picked and the playhead on `frame`.
private func bounce(at frame: Int) -> FlareWorkspace {
    var workspace = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareSample", "bounce"]))
    workspace.selectItem("ball")
    workspace.setCurrentFrame(frame)
    return workspace
}

private func copied(at frame: Int) -> [TypedData] {
    var workspace = bounce(at: frame)
    return FlarePasteboardAdapter(rasterizer: Echo()).copy(&workspace)
}

private func layerNames(_ workspace: FlareWorkspace) -> [String] {
    workspace.document?.layers(of: .scene("scene-1"))?.map(\.name) ?? []
}

/// Two groups, a red square and a blue square: svg-place makes one layer of each.
private let logo = """
<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 200 100">
<g id="red"><rect x="10" y="10" width="80" height="80" fill="#E53935"/></g>
<g id="blue"><rect x="110" y="10" width="80" height="80" fill="#1E88E5"/></g>
</svg>
"""

@Suite struct FlarePasteboardAdapterTests {
    /// The copy offers Flare's own layers, then an SVG, then a PNG, and nothing else.
    @Test func copyOffersOwnLayersSvgAndPng() throws {
        let offered = copied(at: 12)
        #expect(offered.map(\.type) == [.flareLayers, .svg, .png])
        var workspace = bounce(at: 12)
        let own = try #require(offered.first { $0.type == .flareLayers })
        let editCopy = workspace.copy()
        #expect(own.data == editCopy, "the own bytes are Edit > Copy's, so Flare pastes them back as layers")
    }

    /// Mutation `.pngAtPlayhead`: the PNG is drawn at frame 12, at 1x, never at frame 0.
    @Test func pngIsDrawnAtThePlayhead() throws {
        let at12 = try #require(copied(at: 12).first { $0.type == .png })
        let at0 = try #require(copied(at: 0).first { $0.type == .png })
        #expect(at12.data != at0.data, "the PNG at frame 12 is the frame 0 picture")
        #expect(String(decoding: at12.data, as: UTF8.self).hasPrefix("scale 1.0 "), "the PNG isn't drawn at 1x")
        #expect(copied(at: 12).first { $0.type == .png } == at12, "two copies at frame 12 drew different pictures")
        // The picture is frame 12's draw list cropped to Ball's box there, not another frame's list in that box.
        let workspace = bounce(at: 12)
        let document = try #require(workspace.document)
        let services = workspace.services
        let list = services.stage.drawList(document, sceneID: "scene-1", frame: 12, editing: nil)
        let ball = list.items.map(\.address).filter { workspace.editLayerIDs.contains($0.layerID) }
        #expect(!ball.isEmpty, "Ball's layer draws nothing at frame 12")
        let box = try #require(services.hits.bounds(document, sceneID: "scene-1", frame: 12, editing: nil, of: ball))
        let expected = try Echo().png(FlarePasteboardAdapter.cropped(list, to: box), scale: 1, transparent: true)
        #expect(at12.data == expected, "the PNG isn't frame 12's picture of Ball")
    }

    /// The SVG frame is one document holding the squashed ball at frame 12, unlike frame 0's.
    @Test func svgIsTheFrameAtThePlayhead() throws {
        let at12 = try #require(copied(at: 12).first { $0.type == .svg })
        let at0 = try #require(copied(at: 0).first { $0.type == .svg })
        let text = String(decoding: at12.data, as: UTF8.self)
        #expect(text.contains("<svg") && text.contains("</svg>"), "not an SVG document: \(text)")
        #expect(text.contains("<path"), "the SVG frame draws no ball")
        #expect(at12.data != at0.data, "the SVG at frame 12 is the frame 0 drawing")
    }

    /// The coder hands Flare its own layers first, and an SVG beside a PNG as vectors, not pixels.
    @Test func flareTakesOwnLayersThenVectors() throws {
        let coder = SuitePasteboardCoding()
        let offered = copied(at: 12)
        guard case .appLayers(let type, _)? = coder.bestItem(from: offered, for: .flare) else {
            Issue.record("Flare took no layers from its own copy"); return
        }
        #expect(type == .flareLayers)
        let svgAndPng = offered.filter { $0.type != .flareLayers }
        guard case .vector? = coder.bestItem(from: svgAndPng, for: .flare) else {
            Issue.record("Flare took the PNG over the SVG"); return
        }
    }

    /// Mutation `.svgPlacesVectors`: a pasted SVG adds its two groups as layers, one undo step, never a bitmap.
    @Test(.disabled("waits on svg-place PF-5")) func pastedSvgAddsItsGroupsAsLayers() {
        var workspace = bounce(at: 12)
        let before = layerNames(workspace)
        FlarePasteboardAdapter(rasterizer: Echo()).paste(.vector(svg: logo, name: "logo"), into: &workspace)
        let after = layerNames(workspace)
        #expect(after.count == before.count + 2, "the paste added \(after.count - before.count) layers, not 2")
        #expect(workspace.layerError == nil, "the paste refused: \(String(describing: workspace.layerError))")
        workspace.undo()
        #expect(layerNames(workspace) == before, "one undo takes the paste back")
    }

    /// Mutation `.svgPlacesVectors`: a pasted SVG goes to `place.image` as an SVG file, never drawn to pixels first
    /// (Flare refuses pixels with the kernel's format sentence). Until svg-place PF-5 the place path says it isn't
    /// built; after it the SVG's two groups are layers.
    @Test func pastedSvgRunsThePlacePath() {
        var workspace = bounce(at: 12)
        let before = layerNames(workspace)
        FlarePasteboardAdapter(rasterizer: Echo()).paste(.vector(svg: logo, name: "logo"), into: &workspace)
        let added = layerNames(workspace).count - before.count
        let refusal = workspace.layerError?.message
        #expect(refusal != PlaceRules.formatHelp, "the SVG reached place.image as a picture")
        #expect(added == 2 || refusal?.contains("svg-place") == true,
                "the paste neither added the logo's layers nor reached svg-place's place path: \(String(describing: refusal))")
    }

    /// A PNG goes to `place.image` too, which refuses it in Flare's words and changes nothing.
    @Test func pastedPngIsRefusedByThePlacePath() {
        var workspace = bounce(at: 12)
        let before = layerNames(workspace)
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        FlarePasteboardAdapter(rasterizer: Echo()).paste(.image(png: png, pixelWidth: 1, pixelHeight: 1), into: &workspace)
        #expect(layerNames(workspace) == before)
        #expect(workspace.layerError?.message == PlaceRules.formatHelp)
    }

    /// Copy As in the catalog: SVG is the playhead's frame, own is Edit > Copy's bytes, PNG refuses without a window.
    @Test func copyAsGivesSvgAndOwnAndRefusesPngHeadless() throws {
        let workspace = bounce(at: 12)
        let svg = try workspace.copyAs(.svg)
        #expect(svg.type == SuiteTypeID.svg.rawValue)
        #expect(svg.data == copied(at: 12).first { $0.type == .svg }?.data)
        var plain = bounce(at: 12)
        let own = try workspace.copyAs(.own)
        #expect(own.type == SuiteTypeID.flareLayers.rawValue && own.data == plain.copy())
        #expect(throws: CatalogError.self) { try workspace.copyAs(.png) }
    }

    /// Flare's own layers pasted back are Edit > Paste's: "Ball copy", one step.
    @Test func pastedOwnLayersAreACopy() throws {
        var workspace = bounce(at: 12)
        let copy = workspace.copy()
        let own = try #require(copy)
        FlarePasteboardAdapter(rasterizer: Echo()).paste(.appLayers(.flareLayers, own), into: &workspace)
        #expect(layerNames(workspace).contains("Ball copy"), "the paste added no Ball copy")
        #expect(workspace.undoName == "Paste")
    }
}
