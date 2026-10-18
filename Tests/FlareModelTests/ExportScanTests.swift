// ExportScanTests.swift: LM-0c3 (docs/blueprints/flare.md, 7.1): one test per warning, `bounce` 0–12 step 2 gives 7
// PNGs, a cancelled export returns no files, the run on the kernel's ExportRun (FX-4), `showcase`, never a silent
// drop, and QB-L8 on the fake.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import Synchronization
import Testing

private let export = FakeExport()
private let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
private let text = "Text isn't exported yet (1 layer)."
private let symbol = "Symbol animation exports as its first frame (1 instance)."
private let machine = "Interactions aren't exported (1 machine)."
private let background = "Background color isn't part of Lottie."

private func options(_ format: ExportFormat, _ frames: ClosedRange<Int> = 0...0, step: Int = 1,
                     transparent: Bool = false) -> ExportOptions {
    ExportOptions(format: format, sceneID: "scene-1", frames: frames, step: step, transparentBackground: transparent)
}

private func run(_ document: Document, _ options: ExportOptions, using export: FakeExport = export,
                 progress: @Sendable (Double) -> Void = { _ in }) async throws -> ExportResult {
    try await export.export(document, options: options, rasterizer: FakeRasterizer(), progress: progress)
}

private func workspace(_ document: Document) -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake()); w.load(document); return w
}

@Test func aTextLayerIsNamedAndCountedInEveryFormat() {
    var document = FlareFixtures.bounce
    let title = TextShape(string: "Hi", fontFamily: "System", fontSize: 24, position: Point(x: 10, y: 10))
    document.scenes[0].layers.append(Layer(id: "title", name: "Title", texts: [title]))
    #expect(ExportScan.warnings(document, options: options(.svgFrame)) == [text])
    #expect(ExportScan.warnings(document, options: options(.pngSequence)) == [text])
    document.scenes[0].layers[0].texts = [title, title]
    #expect(ExportScan.warnings(document, options: options(.svgFrame)) == ["Text isn't exported yet (2 layers)."])
}

@Test func anAnimatedSymbolInstanceIsNamedButAStillOneIsNot() {
    #expect(ExportScan.warnings(FlareFixtures.character, options: options(.svgFrame)) == [symbol])
    var held = FlareFixtures.character
    held.scenes[0].layers[2].instances[0].loop = .singleFrame
    #expect(ExportScan.warnings(held, options: options(.svgFrame)).isEmpty)
}

@Test func aMachineIsNamed() {
    #expect(ExportScan.warnings(FlareFixtures.buttonWithMachine, options: options(.pngSequence)) == [machine])
    #expect(ExportScan.warnings(FlareFixtures.button, options: options(.pngSequence)).isEmpty)
}

@Test func theBackgroundIsNamedOnlyForAnOpaqueLottie() {
    #expect(ExportScan.warnings(FlareFixtures.bounce, options: options(.lottie)) == [background])
    #expect(ExportScan.warnings(FlareFixtures.bounce, options: options(.lottie, transparent: true)).isEmpty)
    #expect(ExportScan.warnings(FlareFixtures.bounce, options: options(.svgFrame)).isEmpty)
    #expect(ExportScan.warnings(FlareFixtures.bounce, options: ExportOptions(format: .lottie, sceneID: "gone", frames: 0...0)).isEmpty)
}

@Test func showcaseIsValidAndHoldsOneOfEachWarning() throws {
    let showcase = try #require(FlareFixtures.named("showcase"))
    try FlareFormat.validate(showcase)
    #expect(showcase.scenes[0].layers.map(\.name) == ["Background", "Shadow", "Ball", "Spinner", "Title"])
    #expect(showcase.symbols.map(\.name) == ["Spin"] && showcase.stateMachines.count == 1)
    #expect(ExportScan.warnings(showcase, options: options(.svgFrame)) == [text, symbol, machine])
    #expect(ExportScan.warnings(showcase, options: options(.lottie)) == [text, symbol, machine, background])
}

@Test func everyFormatExportsShowcaseCarryingTheScansWarnings() async throws {
    let showcase = FlareFixtures.showcase
    for format in ExportFormat.allCases {
        let o = options(format, 0...2)
        let result = try await run(showcase, o)
        #expect(!result.files.isEmpty)
        #expect(result.warnings == ExportScan.warnings(showcase, options: o))
        #expect(export.warnings(showcase, options: o) == result.warnings)
    }
    let svg = try await run(showcase, options(.svgFrame, 12...12))
    #expect(svg.files.map(\.name) == ["scene-1.svg"] && String(decoding: svg.files[0].data, as: UTF8.self).hasPrefix("<svg"))
    struct Lottie: Decodable { var fr: Int }
    let lottie = try await run(showcase, options(.lottie))
    #expect(lottie.files.map(\.name) == ["scene-1.json"])
    #expect(try JSONDecoder().decode(Lottie.self, from: lottie.files[0].data).fr == 24)
}

@Test func bounceZeroToTwelveStepTwoGivesSevenPNGs() async throws {
    let fractions = Mutex<[Double]>([])
    let result = try await run(FlareFixtures.bounce, options(.pngSequence, 0...12, step: 2)) { p in fractions.withLock { $0.append(p) } }
    #expect(result.files.map(\.name) == (0...6).map { "frame_\(String(repeating: "0", count: $0 < 5 ? 3 : 2))\($0 * 2).png" })
    #expect(result.files.allSatisfy { $0.data.prefix(8) == pngHeader } && result.warnings.isEmpty)
    #expect(fractions.withLock { $0 }.count == 7 && fractions.withLock { $0 }.last == 1)
}

@Test func aCancelledExportReturnsNoFiles() async {
    let task = Task { try await run(FlareFixtures.bounce, options(.pngSequence, 0...47)) }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
}

@Test func anUnavailableExportThrowsItsReasonAndScansNothing() async {
    let off = FakeExport(unavailable: "Not connected yet (IN-7).")
    #expect(off.warnings(FlareFixtures.showcase, options: options(.lottie)).isEmpty)
    await #expect(throws: NotBuilt(reason: "Not connected yet (IN-7).")) {
        try await off.export(FlareFixtures.bounce, options: options(.svgFrame), rasterizer: FakeRasterizer()) { _ in }
    }
}

@Test func aWorkspaceKeepsTheSheetsDefaultsAndWarnings() {
    let w = workspace(FlareFixtures.showcase)
    #expect(w.exportOptions(.pngSequence) == options(.pngSequence, 0...47))
    #expect(w.exportOptions(.lottie).map(w.exportWarnings) == [text, symbol, machine, background])
    let none = FlareWorkspace(services: .fake())
    #expect(none.exportOptions(.svgFrame) == nil && none.exportWarnings(options(.lottie)).isEmpty)
}

// The run tests below are the kernel-shaped rewrite of the old app-local run (FX-2), on since FX-4; the progress one
// reads the run's total, which is `exportFileCount`, on since FX-11.
@Test func aWorkspaceExportRunsThenFinishesWithTheWrittenNames() async throws {
    var w = workspace(FlareFixtures.showcase)
    let document = try #require(w.document)
    #expect(w.openExport() && w.startExport())
    let o = try #require(w.exportingOptions)
    #expect(o == options(.svgFrame, 0...47))
    let result = try await run(document, o)
    #expect(result.warnings == [text, symbol, machine])
    w.endExport(.success(result.files.map(\.name)))
    #expect(w.exportState == .finished(o, ["scene-1.svg"]))
    w.dismissExport()
    #expect(w.exportState == .idle)
    var none = FlareWorkspace(services: .fake())
    #expect(!none.openExport() && !none.startExport() && none.exportState == .idle)
}

@Test func progressOnlyMovesForwardWhileRunning() throws {
    var w = workspace(FlareFixtures.bounce)
    w.exportProgressed(0.5)
    #expect(w.exportState == .idle && w.openExport() && !w.openExport() && w.startExport() && !w.startExport())
    let o = try #require(w.exportingOptions)
    for p in [0.25, 0.1, .nan, 0.75, 4] { w.exportProgressed(p) }
    #expect(w.exportState == .running(o, done: 1, total: 1))
    w.dismissExport()
    #expect(w.exportState == .running(o, done: 1, total: 1))
}

@Test func cancelGoesBackToIdleAndAFailureSaysWhy() throws {
    var w = workspace(FlareFixtures.bounce)
    _ = w.openExport(); _ = w.startExport()
    let o = try #require(w.exportingOptions)
    w.endExport(.failure(CancellationError()))
    #expect(w.exportState == .idle && w.openExport() && w.startExport())
    w.endExport(.failure(PNGExportError.frameOutOfRange(0...90)))
    #expect(w.exportState == .failed(o, "Frames 0–90 aren't all in the scene."))
    w.retryExport(); _ = w.startExport()
    w.endExport(.failure(NotBuilt(reason: "Not connected yet (IN-7).")))
    #expect(w.exportState == .failed(o, "Not connected yet (IN-7)."))
    w.endExport(.success(["scene-1.svg"]))
    #expect(w.exportState == .failed(o, "Not connected yet (IN-7)."))
}

// QB-L8's Linux gate: SVG frame < 1 s, Lottie of 300 frames < 10 s, 48 PNG frames at 1080p < 10 s. The fake's
// 20 ms pause per PNG frame only makes Cancel reachable, so the budget runs without it.
@Test func svgFrameLottieAndPNGSequenceStayInsideQBL8() async throws {
    let straight = FakeExport(frameDelay: .zero), clock = ContinuousClock()
    func hd(_ frames: Int) -> Document {
        var document = FlareFixtures.showcase
        (document.scenes[0].width, document.scenes[0].height, document.scenes[0].durationFrames) = (1920, 1080, frames)
        return document
    }
    let svg = try await clock.measure { _ = try await run(hd(48), options(.svgFrame, 24...24), using: straight) }
    let lottie = try await clock.measure { _ = try await run(hd(300), options(.lottie, 0...299), using: straight) }
    var files = 0
    let png = try await clock.measure { files = try await run(hd(48), options(.pngSequence, 0...47), using: straight).files.count }
    #expect(svg < .seconds(1) && lottie < .seconds(10) && png < .seconds(10) && files == 48)
}
