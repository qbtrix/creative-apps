// PhotoTransformLiftTests.swift: what a Free Transform drag lifts for the compositor (PhotoTransformLift+Kernel.swift).
// The draft's layer lifts when plain overs draw it as the canvas does: the Logo under a visible translucent
// Wash lifts with the Wash as its cover, unless the Logo or the Wash isn't at normal blend; per-pixel
// adjustments tone the sprite and the base, and a blur keeps the layer down. A lift's pixels are the layer's in the box (premultiplied sRGB), its base is the
// workspace without the layer (a selection's keeps the layer outside the box) or the draft, and its placement puts each lifted pixel where the draft's matrix
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

    @Test func aLayerUnderAVisibleLayerLiftsUnderItsCover() throws {
        let covered = try PhotoLiveTransformTests.transforming()
        let key = try #require(covered.liftKey, "the Logo under the Wash lifts (#6259)")
        #expect(key.box == PixelRect(x: 120, y: 80, width: 60, height: 40))
        let lift = try #require(try covered.lifted())
        let cover = try #require(lift.cover, "the Wash rides over the lift as its cover")
        #expect(cover.count == 300 * 200 * 4)
        #expect(cover[3] > 0 && cover[3] < 255, "the cover is the translucent Wash")
        let wash = try #require(covered.layers.first { $0.name == "Wash" })
        let at = try #require(lift.base.index(of: wash.id))
        #expect(!lift.base.layers[at].isVisible, "the Wash is in the cover, not under the lift")
        #expect(try Self.turned().lifted()?.cover == nil, "nothing visible above: no cover")
    }

    @Test func aBlendedLayerOrOneUnderABlendedLayerStaysDown() throws {
        var blended = try Self.turned()
        let id = try #require(blended.transformDraft?.layerID)
        blended.setBlendMode(id, .multiply)
        #expect(blended.liftKey == nil)
        var underMultiply = try PhotoLiveTransformTests.transforming()
        let wash = try #require(underMultiply.layers.first { $0.name == "Wash" })
        underMultiply.setBlendMode(wash.id, .multiply)
        #expect(underMultiply.liftKey == nil, "a multiply cover reads what is under it")
    }

    /// Per-pixel adjustments lift with the sprite toned and the base under it toned (#6259); a blur reads
    /// neighbours across the lift's edge, so it keeps the layer down.
    @Test func perPixelAdjustmentsLiftTonedAndABlurStaysDown() throws {
        var adjusted = try Self.turned()
        adjusted.adjust(.exposure(1))
        _ = try #require(adjusted.liftKey, "an exposure change lifts")
        let lift = try #require(try adjusted.lifted())
        let plain = try #require(try Self.turned().lifted())
        #expect(Array(lift.rgba8.prefix(4)) == Array(plain.rgba8.prefix(4)), "red at +1 EV clips to the same red")
        #expect(lift.base.adjustments == adjusted.adjustments, "the picture under the lift keeps the adjustments")
        #expect(try adjusted.liftSprite != Self.turned().liftSprite, "a sprite toned another way is another sprite")
        var grey = try Self.turned()
        grey.adjust(.setEnabled(.invert, true))
        let inverted = try #require(try grey.lifted())
        #expect(Array(inverted.rgba8.prefix(4)) == [0, 255, 255, 255], "the sprite is toned: inverted red is cyan")
        var blurred = try Self.turned()
        blurred.adjust(.blurSigma(2))
        blurred.adjust(.setEnabled(.blur, true))
        #expect(blurred.liftKey == nil)
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

    /// The picture under a selection's lift keeps the layer's pixels outside the box, as Return does (#5813).
    @Test func theBaseUnderASelectionsLiftKeepsTheRestOfTheLayer() throws {
        var workspace = try PhotoLiveTransformTests.transforming()
        workspace.cancelTransform()
        for layer in workspace.layers where layer.name != "Logo" && layer.isVisible { workspace.toggleVisibility(layer.id) }
        workspace.selection = PixelRect(x: 130, y: 90, width: 20, height: 10)
        try workspace.beginTransform()
        try workspace.setTransform(TransformBox(box: Rect(minX: 130, minY: 140, maxX: 150, maxY: 150)), name: "Move", drag: "m")
        #expect(!workspace.liftsAlone, "the rest of the Logo is under the lift")
        let base = try #require(workspace.liftedBase).composite()
        let clear = try base.pixel(x: 5, y: 5)
        #expect(try base.pixel(x: 125, y: 85) != clear, "the Logo outside the selection stays under the lift")
        #expect(try base.pixel(x: 135, y: 95) == clear, "the lifted part is not under itself")
    }
}
