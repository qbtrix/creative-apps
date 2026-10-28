// PhotoToneCommandTests.swift (tone-controls PT-4): the workspace's ToneTarget bodies, tested on the adapter
// itself. A tone edit goes to the selected adjustment layer, else the image, as one named undo step; steps
// under one drag token fold into one; Sharpen on an adjustment layer is off with its help; Auto reads the
// composite without a step; the kernel's exposure folds into Photo's Exposure; the four tone.* ids are in the
// catalog and the ledger, and their runs (TC-6) do the same. Mutations: PhotoModel.PhotoTone+Kernel (`.layerTone`,
// `.dragIsOneStep`, `.exposureFolds`). Runs on Linux and macOS.
import Foundation
import PhotoModel
import SuiteImaging
import SuiteKernel
import Testing

/// An open 8 x 8 white image on `.fake`.
private func image() throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace(services: .fake)
    try workspace.newCanvas(width: 8, height: 8)
    return workspace
}

/// The image with a new Levels adjustment layer above it, selected.
private func withLayer() throws -> PhotoWorkspace {
    var workspace = try image()
    workspace.addAdjustmentLayer(.levels)
    return workspace
}

/// Adjustment layer `id`'s tone, wherever the selection is.
private func toneOf(_ workspace: PhotoWorkspace, _ id: PhotoLayer.ID) -> ToneSettings? {
    guard case .adjustment(let settings)? = workspace.layers.first(where: { $0.id == id })?.kind else { return nil }
    return settings.tone
}

@Suite struct PhotoToneCommandTests {
    @Test func toneIsOnWithAnImageAndOffWithoutOne() throws {
        let none = PhotoWorkspace(services: .fake)
        #expect(none.toneHelp == "Open an image first." && none.toneSliderHelp(.temperature) == "Open an image first.")
        #expect(throws: CatalogError.self) { var w = none; try w.setTone(.neutral.setting(.tint, to: 5), name: "Tint", drag: nil) }
        #expect(throws: CatalogError.self) { _ = try none.autoToneSuggestion() }
        let open = try image()
        #expect(open.toneHelp == nil && open.toneSliderHelp(.sharpenAmount) == nil && open.toneSliderHelp(.temperature) == nil)
    }

    /// A tone edit on the image is one step named for it, and Undo puts the image back.
    @Test func anImageEditIsOneNamedStep() throws {
        var workspace = try image()
        try workspace.setTone(.neutral.setting(.shadows, to: 40), name: "Shadows", drag: nil)
        #expect(workspace.adjustments.tone.value(.shadows) == 40)
        #expect(workspace.historySteps.count == 2 && workspace.undoActionName == "Undo Shadows")
        try workspace.setTone(.neutral.setting(.shadows, to: 40).setting(.highlights, to: -30), name: "Highlights", drag: nil)
        #expect(workspace.historySteps.count == 3)
        workspace.undo()
        #expect(workspace.toneSettings == .neutral.setting(.shadows, to: 40))
    }

    /// The same settings again records nothing.
    @Test func anUnchangedToneIsNoStep() throws {
        var workspace = try image()
        try workspace.setTone(.neutral, name: "Temperature", drag: nil)
        #expect(workspace.historySteps.count == 1)
    }

    /// MJ-PT step 2: a drag's steps under one token are one undo step; the next drag is another.
    @Test func dragIsOneStep() throws {
        var workspace = try image()
        for value in stride(from: -1.0, through: -25, by: -1) {
            try workspace.setTone(.neutral.setting(.temperature, to: value), name: "Temperature", drag: "d1")
        }
        #expect(workspace.historySteps.count == 2 && workspace.undoActionName == "Undo Temperature")
        #expect(workspace.toneSettings?.value(.temperature) == -25)
        try workspace.setTone(.neutral.setting(.temperature, to: -30), name: "Temperature", drag: "d2")
        #expect(workspace.historySteps.count == 3)
        workspace.undo()
        workspace.undo()
        #expect(workspace.toneSettings == .neutral)
    }

    /// MJ-PT step 4: a layer's tone goes to the layer; the image's stays; Undo puts the layer back.
    @Test func layerTone() throws {
        var workspace = try withLayer()
        let id = try #require(workspace.selectedLayerID)
        try workspace.setTone(.neutral.setting(.contrast, to: 20), name: "Contrast", drag: nil)
        #expect(workspace.adjustments.tone == .neutral)
        #expect(toneOf(workspace, id)?.value(.contrast) == 20 && workspace.toneSettings?.value(.contrast) == 20)
        #expect(workspace.historySteps.count == 3 && workspace.undoActionName == "Undo Contrast")
        workspace.undo()
        #expect(toneOf(workspace, id) == .neutral)
    }

    /// A drag on a layer folds too.
    @Test func aLayerDragIsOneStep() throws {
        var workspace = try withLayer()
        for value in stride(from: 1.0, through: 20, by: 1) {
            try workspace.setTone(.neutral.setting(.contrast, to: value), name: "Contrast", drag: "d1")
        }
        #expect(workspace.historySteps.count == 3 && workspace.adjustments.tone == .neutral)
    }

    /// Sharpen reads neighbours, so a layer can't hold it: the rows say why and setTone refuses.
    @Test func sharpenOnALayerIsUnavailableWithHelp() throws {
        var workspace = try withLayer()
        let id = try #require(workspace.selectedLayerID)
        #expect(workspace.toneHelp == nil && workspace.toneSliderHelp(.contrast) == nil)
        for slider in ToneGroup.sharpen.sliders { #expect(workspace.toneSliderHelp(slider) == "Sharpen is for the image.") }
        #expect(throws: CatalogError.self) {
            try workspace.setTone(.neutral.setting(.sharpenAmount, to: 80), name: "Amount", drag: nil)
        }
        #expect(toneOf(workspace, id) == .neutral && workspace.adjustments.tone == .neutral)
        #expect(workspace.historySteps.count == 2)
    }

    /// MJ-PT step 3: Auto reads the composite and records nothing.
    @Test func autoSuggestionReadsTheImage() throws {
        let workspace = try image()
        let auto = try workspace.autoToneSuggestion()
        #expect(auto.inWhite > auto.inBlack && workspace.historySteps.count == 1)
    }

    @Test func idListMatchesCatalog() throws {
        let ids = ToneCommands.specs(PhotoWorkspace.self).map(\.id)
        #expect(ids == ["tone.read", "tone.set", "tone.reset", "tone.auto"])
        #expect(ids.allSatisfy(PhotoWorkspace.catalog.ids.contains))
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/photo.txt")
        let ledger = Set(try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init))
        #expect(ids.filter { !ledger.contains($0) } == [])
        #expect(PhotoWorkspace.catalog.availability("tone.set", on: try image()).why == nil)
        #expect(PhotoWorkspace.catalog.availability("tone.set", on: PhotoWorkspace(services: .fake)).why == "Open an image first.")
    }

    /// The same layer edit through the command.
    @Test func toneSetCommandOnALayerChangesTheLayerOnly() throws {
        var workspace = try withLayer()
        let params = JSONValue.object(["slider": .string("contrast"), "value": .number(20)])
        _ = try PhotoWorkspace.catalog.run("tone.set", params: params, on: &workspace)
        #expect(workspace.adjustments.tone == .neutral && workspace.toneSettings?.value(.contrast) == 20)
        #expect(workspace.historySteps.count == 3)
    }

    /// A drag through the command is one step.
    @Test func toneSetCommandDragIsOneStep() throws {
        var workspace = try image()
        for value in stride(from: 1.0, through: 10, by: 1) {
            let params = JSONValue.object(["slider": .string("tint"), "value": .number(value), "drag": .string("d1")])
            _ = try PhotoWorkspace.catalog.run("tone.set", params: params, on: &workspace)
        }
        #expect(workspace.historySteps.count == 2 && workspace.undoActionName == "Undo Tint")
    }

    /// Photo has one exposure: the kernel's folds into Exposure's stops (turned on) and the tone keeps 0.
    @Test func kernelExposureFoldsIntoPhotosExposure() throws {
        var workspace = try image()
        workspace.adjust(.setEnabled(.exposure, false))
        try workspace.setTone(.neutral.setting(.exposure, to: 0.5).setting(.whites, to: 10), name: "Auto Tone", drag: nil)
        #expect(workspace.adjustments.exposure == 0.5 && workspace.adjustments.isEnabled(.exposure))
        #expect(workspace.toneSettings == .neutral.setting(.whites, to: 10))
        #expect(workspace.undoActionName == "Undo Auto Tone")
        workspace.undo()
        #expect(workspace.adjustments.exposure == 0 && workspace.toneSettings == .neutral)
    }

    /// tone.set exposure is refused with the reason, and the row says it too.
    @Test func toneSetExposureIsRefused() throws {
        var workspace = try image()
        #expect(workspace.toneSliderHelp(.exposure) == "Use Photo's Exposure.")
        let params = JSONValue.object(["slider": .string("exposure"), "value": .number(1)])
        #expect(throws: CatalogError.self) { _ = try PhotoWorkspace.catalog.run("tone.set", params: params, on: &workspace) }
        #expect(workspace.adjustments.exposure == 0 && workspace.historySteps.count == 1)
    }

    /// tone.auto on the sample picture, which has a range of tones, is one step named "Auto Tone".
    @Test func toneAutoIsOneNamedStep() throws {
        var workspace = try PhotoWorkspace.fixture(.sample)
        let steps = workspace.historySteps.count
        _ = try PhotoWorkspace.catalog.run("tone.auto", params: .object([:]), on: &workspace)
        #expect(workspace.historySteps.count == steps + 1 && workspace.undoActionName == "Undo Auto Tone")
    }
}
