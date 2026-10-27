// PhotoTransformLiftTests.swift: what a Free Transform drag lifts for the compositor (PhotoTransformLift.swift).
// The draft's layer lifts only when a plain over draws it as the canvas does: here the Logo under a visible
// translucent Wash doesn't lift, and does once the Wash is hidden, unless its blend mode isn't normal or the
// image's adjustments change it. A lift's pixels are the layer's in the box (premultiplied sRGB), its base is the
// workspace without the layer or the draft, and its placement puts each lifted pixel where the draft's matrix
// (the one commit resamples through) puts that layer pixel. Runs on Linux and macOS.
import CoreRaster
import Foundation
import SuiteKernel
import Testing

@testable import PhotoModel

@Suite struct PhotoTransformLiftTests {
    /// PhotoLiveTransformTests' Logo, turned 30° and moved, with the Wash over it hidden.
    static func turned() throws -> PhotoWorkspace {
        var workspace = try PhotoLiveTransformTests.transforming()
        let wash = try #require(workspace.layers.first { $0.name == "Wash" })
        workspace.toggleVisibility(wash.id)
        var box = try #require(workspace.transformSelection)
        box.degrees = 30
        box.box = Rect(minX: box.box.minX + 7, minY: box.box.minY - 3, maxX: box.box.maxX + 7, maxY: box.box.maxY - 3)
        try workspace.setTransform(box, name: "Rotate", drag: "t")
        return workspace
    }

    @Test func aLayerUnderAVisibleLayerDoesNotLiftAndLiftsOnceItIsHidden() throws {
        let covered = try PhotoLiveTransformTests.transforming()
        #expect(covered.liftKey == nil)
        let workspace = try Self.turned()
        let key = try #require(workspace.liftKey)
        #expect(key.box == PixelRect(x: 120, y: 80, width: 60, height: 40))
    }

    @Test func aBlendModeOrAdjustmentKeepsTheLayerDown() throws {
        var blended = try Self.turned()
        let id = try #require(blended.transformDraft?.layerID)
        blended.setBlendMode(id, .multiply)
        #expect(blended.liftKey == nil)
        var adjusted = try Self.turned()
        adjusted.adjust(.exposure(0.5))
        #expect(adjusted.liftKey == nil)
    }

    @Test func theLiftIsTheLayersPixelsOverTheWorkspaceWithoutIt() throws {
        let workspace = try Self.turned()
        let lift = try #require(try workspace.lifted())
        #expect((lift.width, lift.height) == (60, 40))
        #expect(lift.rgba8.count == 60 * 40 * 4)
        #expect(Array(lift.rgba8.prefix(4)) == [255, 0, 0, 255], "the Logo is opaque red")
        let at = try #require(lift.base.index(of: lift.key.layerID))
        #expect(lift.base.layers[at].isVisible == false && lift.base.transformDraft == nil)
        #expect(lift.base.liftKey == nil)
    }

    @Test func thePlacementIsTheDraftsMatrix() throws {
        let workspace = try Self.turned()
        let draft = try #require(workspace.transformDraft)
        let place = try #require(workspace.liftPlacement)
        let m = try workspace.services.transform.matrix(draft, origin: (120, 80))
        // The lift starts at the layer's own top-left here (the box is the whole Logo).
        for (x, y) in [(0.0, 0.0), (60.0, 0.0), (0.0, 40.0), (60.0, 40.0)] {
            let got = (place.a * x + place.c * y + place.tx, place.b * x + place.d * y + place.ty)
            let want = (m.a * x + m.c * y + m.tx, m.b * x + m.d * y + m.ty)
            #expect(abs(got.0 - want.0) < 1e-9 && abs(got.1 - want.1) < 1e-9)
        }
        #expect(abs(atan2(place.b, place.a) * 180 / .pi - 30) < 1e-6, "the placement turns 30°")
    }

    /// A box on part of the layer (a selection) lifts that part, placed where the matrix puts its layer pixels.
    @Test func aSelectionLiftsItsPartAtItsPlace() throws {
        var workspace = try PhotoLiveTransformTests.transforming()
        workspace.cancelTransform()
        let wash = try #require(workspace.layers.first { $0.name == "Wash" })
        workspace.toggleVisibility(wash.id)
        workspace.selection = PixelRect(x: 130, y: 90, width: 20, height: 10)
        try workspace.beginTransform()
        var box = try #require(workspace.transformSelection)
        box.degrees = 15
        try workspace.setTransform(box, name: "Rotate", drag: "t")
        let lift = try #require(try workspace.lifted())
        #expect(lift.key.box == PixelRect(x: 130, y: 90, width: 20, height: 10) && (lift.width, lift.height) == (20, 10))
        let place = try #require(workspace.liftPlacement)
        let m = try workspace.services.transform.matrix(try #require(workspace.transformDraft), origin: (120, 80))
        // Lifted pixel (0, 0) is layer pixel (10, 10).
        #expect(abs(place.tx - (m.a * 10 + m.c * 10 + m.tx)) < 1e-9 && abs(place.ty - (m.b * 10 + m.d * 10 + m.ty)) < 1e-9)
    }
}
