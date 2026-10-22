// FlarePlaceMenuTests.swift (svg-place PF-3): File > Place… and the drop on Flare's workspace: off until an animation
// is open; a refusal adds nothing and says why in the status line, in Flare's words. The SVG report waits on PF-5.
import Foundation
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlarePlaceMenuTests {
    /// One empty 480×270 scene, opened on `.built`.
    private func blank() -> FlareWorkspace {
        var w = FlareWorkspace(services: .built)
        w.load(Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", width: 480, height: 270)]))
        return w
    }

    /// A PNG's signature and a little padding: enough for the format sniff.
    private let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] + [UInt8](repeating: 0, count: 24))

    /// The journey kit's drawing: a red group and a blue group, 240×80.
    private let twoGroups = Data(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"240\" height=\"80\">"
        + "<g id=\"red\"><rect width=\"100\" height=\"80\" fill=\"#E53935\"/></g>"
        + "<g id=\"blue\"><rect x=\"140\" width=\"100\" height=\"80\" fill=\"#1E88E5\"/></g></svg>").utf8)

    @Test func noAnimationTurnsPlaceOff() {
        #expect(FlareWorkspace(services: .built).placeMenuHelp == FlareLayerError.noDocument.message)
        #expect(blank().placeMenuHelp == nil)
    }

    @Test func noAnimationRefusesWithItsReason() {
        var w = FlareWorkspace(services: .built)
        w.place([(name: "two-groups.svg", data: twoGroups)])
        #expect(w.placeStatus == FlareLayerError.noDocument.message)
        #expect(w.document == nil)
    }

    @Test func pngRefusesInFlaresWords() {
        var w = blank()
        let before = w.document
        w.place([(name: "photo.png", data: png)])
        #expect(w.placeStatus == "Flare places SVG files.")
        #expect(w.document == before)
        #expect(w.canUndo == false)
    }

    @Test func statusLineShowsThePlace() {
        var w = blank()
        #expect(w.statusPills(measuredFPS: nil).placeNote == nil)
        w.place([(name: "photo.png", data: png)])
        #expect(w.statusPills(measuredFPS: nil).placeNote == "Flare places SVG files.")
        w.newDocument()
        #expect(w.placeStatus == nil)
    }

    @Test func refusalsReadAsTheirReason() {
        #expect(FlareWorkspace.placeRefusal(.failed(id: "place.image", message: "The SVG is damaged.")) == "The SVG is damaged.")
        #expect(FlareWorkspace.placeRefusal(.unavailable(id: "place.image", why: "Unlock it.")) == "Unlock it.")
    }

    @Test(.disabled("waits on PF-5")) func svgPlaceReportsInStatus() {
        var w = blank()
        w.place([(name: "two-groups.svg", data: twoGroups)])
        #expect(w.placeStatus == "Placed two-groups.svg: 2 layers.")
        #expect(w.undoName == "Place Image")
    }
}
