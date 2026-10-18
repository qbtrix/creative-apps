// FlareExportTests.swift: MJ-FX1's run transitions over the kernel's ExportRun
// (docs/blueprints/flare/features/flare-export.md, FX-2 and FX-4). `shape`: Flare's ExportState is the kernel's
// ExportRun<ExportOptions>, and with nothing open every transition changes nothing. The rest are MJ-FX1 and the FX-4
// mutations; the ones that read FX-11's setters, `exportProblem`, `exportSummary` or the refusal sentences wait on
// FX-11, and the others place the run directly so they hold FX-4's transitions on their own.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

private let sevenPNGs = ExportOptions(format: .pngSequence, sceneID: "scene-1", frames: 0...12, step: 2)
private let names = (0...6).map { "frame_\(String(repeating: "0", count: $0 < 5 ? 3 : 2))\($0 * 2).png" }

private func showcase() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake()); w.load(FlareFixtures.showcase); return w
}

/// `showcase` editing the PNG sequence 0...12 step 2 (7 files), placed on the run (`walk` reaches it by the setters).
private func editingSevenPNGs() -> FlareWorkspace {
    var w = showcase(); w.exportState = .editing(sevenPNGs); return w
}

/// The same run, started at 0 of 7.
private func runningSevenPNGs() -> FlareWorkspace {
    var w = showcase(); w.exportState = .running(sevenPNGs, done: 0, total: 7); return w
}

struct FlareExportTests {
    @Test func shape() {
        let idle: ExportRun<ExportOptions> = ExportState.idle
        var w = FlareWorkspace(services: .fake())
        #expect(w.exportState == idle)
        let before = w
        #expect(!w.openExport() && !w.startExport() && w.exportingOptions == nil)
        w.exportProgressed(0.5); w.exportProgressed(.nan)
        w.endExport(.success(["scene-1.svg"])); w.endExport(.failure(CancellationError()))
        w.endExport(.failure(ExportWriteRefusal.cantWrite(folder: "Locked")))
        w.retryExport(); w.dismissExport()
        #expect(w == before && w.exportState == .idle)
        let states: [ExportState] = [.editing(sevenPNGs), .running(sevenPNGs, done: 0, total: 7),
                                     .finished(sevenPNGs, names), .failed(sevenPNGs, "Disk full.")]
        #expect(Set(states).count == 4 && !states.contains(.idle))
    }

    @Test(.disabled("waits on FX-11")) func walk() {
        var w = showcase()
        let opened = w.openExport()
        #expect(opened)
        #expect(w.exportState == .editing(ExportOptions(format: .svgFrame, sceneID: "scene-1", frames: 0...47)))
        w.setExportFormat(.pngSequence); w.setExportFrames(0...12); w.setExportStep(2)
        #expect(w.exportFileCount == 7 && w.exportProblem == nil)
        #expect(w.startExport() && w.exportState == .running(sevenPNGs, done: 0, total: 7))
        w.exportProgressed(0.5)
        #expect(w.exportState == .running(sevenPNGs, done: 3, total: 7))
        w.exportProgressed(0.2)
        #expect(w.exportState == .running(sevenPNGs, done: 3, total: 7))
        w.endExport(.success(names))
        #expect(w.exportState == .finished(sevenPNGs, names) && w.exportSummary == "Exported 7 files.")
        w.dismissExport()
        #expect(w.exportState == .idle && w.exportingOptions == nil)
    }

    @Test(.disabled("waits on FX-11")) func startRefusesABadRange() {
        var w = editingSevenPNGs()
        w.setExportFrames(0...90)
        let before = w
        #expect(!w.startExport() && w == before)
        #expect(w.exportState == .editing(ExportOptions(format: .pngSequence, sceneID: "scene-1", frames: 0...90, step: 2)))
    }

    @Test func dismissKeepsARunningRun() {
        var w = runningSevenPNGs()
        w.dismissExport()
        #expect(w.exportState == .running(sevenPNGs, done: 0, total: 7))
        var editing = editingSevenPNGs()
        editing.dismissExport()
        #expect(editing.exportState == .idle)
    }

    @Test func cancelReturnsToIdle() {
        var w = runningSevenPNGs()
        w.endExport(.failure(CancellationError()))
        #expect(w.exportState == .idle && w.exportingOptions == nil)
    }

    @Test(.disabled("waits on FX-11")) func aFailureCarriesTheSheetsSentence() {
        var w = runningSevenPNGs()
        w.endExport(.failure(ExportWriteRefusal.alreadyThere(name: "scene-1.svg", folder: "Exports")))
        #expect(w.exportState == .failed(sevenPNGs, "scene-1.svg is already in Exports. Choose another folder."))
        #expect(w.exportingOptions == sevenPNGs && w.exportSummary == nil)
    }

    @Test func progressFloorsTheFraction() {
        var w = runningSevenPNGs()
        w.exportProgressed(0.5)
        #expect(w.exportState == .running(sevenPNGs, done: 3, total: 7))
        w.exportProgressed(.nan); w.exportProgressed(-1)
        #expect(w.exportState == .running(sevenPNGs, done: 3, total: 7))
        w.exportProgressed(4)
        #expect(w.exportState == .running(sevenPNGs, done: 7, total: 7))
    }

    @Test func progressIsOnePerFrame() {
        var w = runningSevenPNGs()
        w.exportProgressed(0.5)
        let atThree = w
        w.exportProgressed(0.45)
        #expect(w == atThree)
        w.exportProgressed(0.58)
        #expect(w != atThree && w.exportState == .running(sevenPNGs, done: 4, total: 7))
    }

    @Test func retryOnlyFromFailed() {
        var finished = runningSevenPNGs()
        finished.endExport(.success(names))
        let done = finished
        finished.retryExport()
        #expect(finished == done)
        var failed = runningSevenPNGs()
        failed.endExport(.failure(ExportWriteRefusal.cantWrite(folder: "Locked")))
        failed.retryExport()
        #expect(failed.exportState == .editing(sevenPNGs) && failed.startExport())
    }
}
