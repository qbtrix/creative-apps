// PhotoV2StateTests.swift: the v2 stored state of PV-0 (blueprint 5.3,
// photo-seams S-6a): a workspace starts on `.live`, `services` stays out of
// `==`, `start()` resets the per-image v2 fields, loaded layer ids are never
// handed out again, adjustment settings round-trip through JSON, and Delete
// Layer reports its geometry change once. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoV2StateTests {
    @Test func newWorkspaceIsLive() {
        let workspace = PhotoWorkspace()
        let sampling = String(describing: type(of: workspace.services.sampling))
        #expect(sampling == String(describing: type(of: PhotoServices.live.sampling)))
        #expect(!sampling.hasPrefix("Fake"))
    }

    @Test func eyedropperHelpComesFromSampling() {
        let live = PhotoWorkspace()
        #expect(live.toolHelp(.eyedropper) == live.services.sampling.unavailableHelp)
        #expect(live.toolHelp(.eyedropper) == "Not built yet (PV-9).")
        #expect(PhotoTool.eyedropper.unavailableHelp == "Not built yet (PV-9).")
        let fake = PhotoWorkspace(services: .fake)
        #expect(fake.toolHelp(.eyedropper) == nil)
        for tool in PhotoTool.allCases where tool != .eyedropper {
            #expect(live.toolHelp(tool) == tool.unavailableHelp)
        }
    }

    @Test func startResetsEveryV2Field() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        dirty(&workspace)
        try workspace.open(rgba8: [255, 0, 0, 255], width: 1, height: 1, name: "red.png")
        expectReset(workspace)
        dirty(&workspace)
        try workspace.newCanvas(width: 2, height: 2)
        expectReset(workspace)
    }

    @Test func servicesStayOutOfEquality() {
        let live = PhotoWorkspace()
        let fake = PhotoWorkspace(services: .fake)
        #expect(live == fake)
    }

    @Test func reservedIDsAreNeverHandedOut() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 2, height: 2)
        workspace.reserveLayerIDs(after: 40)
        let id = workspace.insertLayer(named: "Loaded", pixels: nil, kind: .pixels, at: 0)
        #expect(id == "layer-41")
        workspace.reserveLayerIDs(after: 3)
        #expect(workspace.insertLayer(named: "Next", pixels: nil, kind: .pixels, at: 0) == "layer-42")
    }

    @Test func adjustmentLayerHoldsSettingsWithoutPixels() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 2, height: 2)
        var settings = AdjustmentSettings()
        settings.apply(.exposure(1))
        let id = workspace.insertLayer(named: "Curves 1", pixels: nil, kind: .adjustment(settings), at: 0)
        #expect(workspace.pixels[id] == nil)
        #expect(workspace.layers.first?.kind == .adjustment(settings))
        #expect(workspace.layers.first?.hasMask == false)
        #expect(workspace.layers.first?.isMaskEnabled == true)
    }

    @Test func adjustmentSettingsRoundTripThroughJSON() throws {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(1.5))
        settings.apply(.blackPoint(0.1))
        settings.apply(.gamma(1.7))
        settings.apply(.curvePoints([CurvePoint(x: 0, y: 0.1), CurvePoint(x: 0.5, y: 0.7), CurvePoint(x: 1, y: 1)]))
        settings.apply(.blurSigma(2))
        settings.apply(.hue(30))
        settings.apply(.setEnabled(.levels, false))
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AdjustmentSettings.self, from: data)
        #expect(decoded == settings)
        #expect(decoded.hashValue == settings.hashValue)
    }

    @Test func deletingALayerReportsItsRemovalOnce() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 2, height: 2)
        workspace.addLayer()
        let id = try #require(workspace.selectedLayerID)
        let before = workspace.geometryChangeCount
        let removed = workspace.removeLayer(id)
        #expect(removed)
        #expect(workspace.geometryChangeCount == before + 1)
        #expect(workspace.lastGeometryChange?.id == id)
        #expect(workspace.lastGeometryChange?.change == .removed)
    }

    @Test func clearStatusDropsTheMessage() {
        var workspace = PhotoWorkspace()
        workspace.statusMessage = "Nothing to paste."
        workspace.clearStatus()
        #expect(workspace.statusMessage == nil)
    }

    /// Sets every v2 field `start()` resets to a non-default value.
    private func dirty(_ workspace: inout PhotoWorkspace) {
        workspace.selectionMask = try? Mask(width: 1, height: 1, fill: 1)
        if let id = workspace.selectedLayerID {
            workspace.masks[id] = try? TiledPixels(width: 1, height: 1)
            workspace.transformDraft = TransformDraft(layerID: id, box: PixelRect(x: 0, y: 0, width: 1, height: 1))
        }
        workspace.editsMask = true
        workspace.statusMessage = "Nothing to paste."
        workspace.fileKind = .document
        #expect(workspace.selectionMask != nil)
        #expect(!workspace.masks.isEmpty)
        #expect(workspace.transformDraft != nil)
    }

    private func expectReset(_ workspace: PhotoWorkspace) {
        #expect(workspace.selectionMask == nil)
        #expect(workspace.masks.isEmpty)
        #expect(workspace.editsMask == false)
        #expect(workspace.transformDraft == nil)
        #expect(workspace.statusMessage == nil)
        #expect(workspace.fileKind == nil)
    }
}
