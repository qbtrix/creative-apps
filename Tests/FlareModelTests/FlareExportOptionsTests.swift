// FlareExportOptionsTests.swift: MJ-FX1's readouts and setters (docs/blueprints/flare/features/flare-export.md).
// `shape`: the declared API exists, and with nothing open every readout is empty and every call changes nothing. The
// rest are written from MJ-FX1 (contract rule 13) and hold FX-11's readouts, setters and sentences.
import FlareCore
@testable import FlareModel
import Testing

private func showcase() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake()); w.load(FlareFixtures.showcase); return w
}

private func editing(_ change: (inout FlareWorkspace) -> Void = { _ in }) -> FlareWorkspace {
    var w = showcase(); _ = w.openExport(); change(&w); return w
}

struct FlareExportOptionsTests {
    @Test func shape() {
        var w = FlareWorkspace(services: .fake())
        let before = w
        #expect(!w.openExport() && !w.startExport())
        w.setExportFormat(.pngSequence); w.setExportFrames(0...12); w.setExportStep(2)
        w.setExportScale(2); w.setExportTransparent(true); w.retryExport()
        #expect(w == before && w.exportState == .idle && w.exportingOptions == nil)
        #expect(w.exportFileCount == 0 && w.exportSummary == nil)
        let problem: String? = w.exportProblem
        _ = problem
        let refusal: any Error = ExportWriteRefusal.alreadyThere(name: "scene-1.svg", folder: "Exports")
        #expect((refusal as? ExportWriteRefusal) != .cantWrite(folder: "Exports"))
        #expect(ExportRefusal(description: "Flare can't write to Locked.").description == "Flare can't write to Locked.")
    }

    @Test func openingReadsTheSVGFrameDefaults() {
        let w = editing()
        #expect(w.exportingOptions == ExportOptions(format: .svgFrame, sceneID: "scene-1", frames: 0...47))
        #expect(w.exportFileCount == 1 && w.exportProblem == nil && w.exportSummary == nil)
    }

    @Test func pngCountFollowsStep() {
        let w = editing { $0.setExportFormat(.pngSequence); $0.setExportFrames(0...12); $0.setExportStep(2) }
        #expect(w.exportFileCount == 7 && w.exportProblem == nil)
        #expect(editing { $0.setExportFormat(.pngSequence); $0.setExportFrames(0...12) }.exportFileCount == 13)
    }

    @Test func oneFileFormatsCountOne() {
        #expect(editing { $0.setExportFormat(.lottie) }.exportFileCount == 1)
        #expect(editing { $0.setExportFormat(.svgFrame); $0.setExportFrames(3...20) }.exportFileCount == 1)
    }

    @Test func problemNamesFramesPastTheEnd() {
        let past = editing { $0.setExportFrames(0...48) }
        #expect(past.exportProblem == "Frames 0–48 aren't all in the scene." && past.exportFileCount == 0)
        #expect(past.exportingOptions?.frames == 0...48)
        #expect(editing { $0.setExportFrames(0...90) }.exportProblem == "Frames 0–90 aren't all in the scene.")
        #expect(editing { $0.setExportFrames(0...47) }.exportProblem == nil)
    }

    @Test func problemNamesTheStepAndTheScale() {
        let step = editing { $0.setExportFormat(.pngSequence); $0.setExportStep(0) }
        #expect(step.exportProblem == "The frame step must be 1 or more." && step.exportFileCount == 0)
        #expect(editing { $0.setExportScale(3) }.exportProblem == "Scale must be 1x or 2x.")
        #expect(editing { $0.setExportScale(2) }.exportProblem == nil)
    }

    @Test func problemWithNoDocumentAsksForOne() {
        let none = FlareWorkspace(services: .fake())
        #expect(none.exportProblem == "Open or create an animation first." && none.exportFileCount == 0)
    }

    @Test func formatKeepsTheOtherOptions() {
        let w = editing {
            $0.setExportFrames(2...30); $0.setExportStep(3); $0.setExportScale(2); $0.setExportTransparent(true)
            $0.setExportFormat(.pngSequence); $0.setExportFormat(.lottie)
        }
        #expect(w.exportingOptions == ExportOptions(format: .lottie, sceneID: "scene-1", frames: 2...30, step: 3,
                                                    scale: 2, transparentBackground: true))
    }

    @Test func settersChangeNothingWhileIdle() {
        var w = showcase()
        let before = w
        w.setExportFormat(.lottie); w.setExportFrames(0...3); w.setExportStep(2)
        w.setExportScale(2); w.setExportTransparent(true)
        #expect(w == before && w.exportingOptions == nil && w.exportSummary == nil)
    }

    @Test func summaryNamesTheOneFile() {
        var one = editing()
        let oneStarted = one.startExport()
        one.endExport(.success(["scene-1.svg"]))
        #expect(oneStarted && one.exportSummary == "Exported scene-1.svg.")
        var two = editing { $0.setExportFormat(.pngSequence); $0.setExportFrames(0...1) }
        let twoStarted = two.startExport()
        #expect(twoStarted)
        two.endExport(.success(["frame_0000.png", "frame_0001.png"]))
        #expect(two.exportSummary == "Exported 2 files.")
    }

    @Test func refusalsReadAsTheSheetsSentences() {
        let there = ExportWriteRefusal.alreadyThere(name: "scene-1.svg", folder: "Exports")
        #expect(FlareWorkspace.exportMessage(there) == "scene-1.svg is already in Exports. Choose another folder.")
        #expect(FlareWorkspace.exportMessage(ExportWriteRefusal.cantWrite(folder: "Locked")) == "Flare can't write to Locked.")
        #expect(FlareWorkspace.exportMessage(NotBuilt(reason: "Not connected yet (IN-7).")) == "Not connected yet (IN-7).")
    }
}
