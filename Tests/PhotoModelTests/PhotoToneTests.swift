// PhotoToneTests.swift (tone-controls PT-1; PT-3 and PT-4 turn on the rest):
// the image's and an adjustment layer's `tone` section and the workspace as a
// ToneTarget. On now: the section starts neutral, `.tone` sets it, a neutral
// section is left out of the stored form, and the adapter reads the selected
// adjustment layer's tone, else the image's. MJ-PT's walk (one undo step per
// command, a layer's tone stays on the layer) waits on the bodies. Mutations
// (PT-4): PhotoModel.PhotoTone+Kernel (`.layerTone`). Runs on Linux and macOS.
import Foundation
import PhotoModel
import SuiteImaging
import Testing

/// An open 8 x 8 white image on `.fake`.
private func image() throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace(services: .fake)
    try workspace.newCanvas(width: 8, height: 8)
    return workspace
}

private let warm = ToneSettings.neutral.setting(.temperature, to: 30)

@Suite struct PhotoToneTests {
    @Test func sectionStartsNeutralAndToneEditSetsIt() {
        var settings = AdjustmentSettings()
        #expect(settings.tone == .neutral && settings.isIdentity)
        settings.apply(.tone(warm))
        #expect(settings.tone == warm && !settings.isIdentity)
        settings.apply(.tone(.neutral))
        #expect(settings.isIdentity)
    }

    @Test func storedFormOmitsANeutralToneAndKeepsAnother() throws {
        let plain = try JSONEncoder().encode(AdjustmentSettings())
        #expect(!String(decoding: plain, as: UTF8.self).contains("\"tone\""))
        #expect(try JSONDecoder().decode(AdjustmentSettings.self, from: plain).tone == .neutral)
        var settings = AdjustmentSettings()
        settings.apply(.tone(warm))
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(AdjustmentSettings.self, from: data) == settings)
    }

    @Test func noImageHasNoToneAndSaysWhy() {
        let workspace = PhotoWorkspace(services: .fake)
        #expect(workspace.toneSettings == nil)
        #expect(workspace.toneHelp == "Open an image first.")
    }

    @Test func readsTheImageElseTheSelectedAdjustmentLayer() throws {
        var workspace = try image()
        #expect(workspace.toneSettings == .neutral)
        workspace.adjust(.tone(warm))
        #expect(workspace.toneSettings == warm)
        workspace.addAdjustmentLayer(.levels)
        #expect(workspace.toneSettings == .neutral)
        workspace.selectLayer(try #require(workspace.layers.last).id)
        #expect(workspace.toneSettings == warm)
    }

    @Test func aToneEditOnTheImageIsOneNamedStep() throws {
        var workspace = try image()
        workspace.adjust(.tone(warm))
        workspace.adjust(.tone(warm.setting(.temperature, to: 40)))
        #expect(workspace.historySteps.count == 1 && workspace.undoActionName == "Undo Tone")
        workspace.undo()
        #expect(workspace.adjustments.tone == .neutral)
    }
}

@Suite(.disabled("waits on PT-4: setTone and autoToneSuggestion bodies")) struct PhotoToneTargetTests {
    /// MJ-PT step 2: one `setTone` under a drag token is one step named for it.
    @Test func dragIsOneStep() throws {
        var workspace = try image()
        for value in stride(from: -1.0, through: -25, by: -1) {
            try workspace.setTone(.neutral.setting(.temperature, to: value), name: "Temperature", drag: "d1")
        }
        #expect(workspace.historySteps.count == 1 && workspace.undoActionName == "Undo Temperature")
        workspace.undo()
        #expect(workspace.toneSettings == .neutral)
    }

    /// MJ-PT step 4: a layer's tone goes to the layer; the image's stays.
    @Test func layerTone() throws {
        var workspace = try image()
        workspace.addAdjustmentLayer(.levels)
        try workspace.setTone(.neutral.setting(.contrast, to: 20), name: "Contrast", drag: nil)
        #expect(workspace.adjustments.tone == .neutral)
        #expect(workspace.toneSettings?.value(.contrast) == 20)
        #expect(workspace.historySteps.count == 2)
    }

    /// MJ-PT step 3: Auto reads the image without recording a step.
    @Test func autoSuggestionReadsTheImage() throws {
        let workspace = try image()
        let auto = try workspace.autoToneSuggestion()
        #expect(auto.inWhite > auto.inBlack && workspace.historySteps.isEmpty)
    }
}
