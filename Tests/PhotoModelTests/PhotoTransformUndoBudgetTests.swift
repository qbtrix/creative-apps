// PhotoTransformUndoBudgetTests.swift: the real-size budget for Free
// Transform's one undo step (#6201, adopt-kernel-undo #1934). On a 6000 x
// 4000 (24 MP) canvas with the live services, a 600 x 600 layer is scaled 2x
// and committed once, untimed; then each round times one Undo and one Redo of
// that "Free Transform" step, and each round of the Escape test times one
// cancel of a begun, 2x-scaled draft, which takes the Scale step back. All
// are key-repeat actions, so each must land
// within one frame: p95 at or under 8 ms (docs/render-contract.md rule 3)
// over 20 rounds. As in PhotoEditBudgetTests, a release build gates the p95
// (`swift test -c release -Xswiftc -enable-testing --filter
// PhotoTransformUndoBudgetTests`) and debug, which CI runs, only reports it
// and gates the sample count and the steps. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

#if DEBUG
private let gated = false
#else
private let gated = true
#endif
private let rounds = 20

@Suite struct PhotoTransformUndoBudgetTests {
    @Test func undoAndRedoOfAFreeTransformFitOneFrameOn24Megapixels() throws {
        var workspace = try canvasWithASquare()
        let before = workspace.historySteps
        try workspace.beginTransform()
        let box = try #require(workspace.transformSelection)
        try workspace.setTransform(TransformRules.scaled(box, sx: 2, sy: 2, about: .topLeft), name: "Scale", drag: nil)
        try workspace.commitTransform()
        #expect(workspace.historySteps == before + ["Free Transform"])
        let clock = ContinuousClock()
        var undos: [Duration] = [], redos: [Duration] = []
        for _ in 0..<rounds {
            undos.append(clock.measure { workspace.undo() })
            #expect(workspace.transformDraft == nil && workspace.redoActionName == "Redo Free Transform")
            redos.append(clock.measure { workspace.redo() })
            #expect(workspace.undoActionName == "Undo Free Transform")
        }
        check("Free Transform undo", undos)
        check("Free Transform redo", redos)
    }

    @Test func escapeAfterAScaleFitsOneFrameOn24Megapixels() throws {
        var workspace = try canvasWithASquare()
        let before = workspace.historySteps
        let clock = ContinuousClock()
        var cancels: [Duration] = []
        for _ in 0..<rounds {
            try workspace.beginTransform()
            let box = try #require(workspace.transformSelection)
            try workspace.setTransform(TransformRules.scaled(box, sx: 2, sy: 2, about: .topLeft), name: "Scale", drag: nil)
            cancels.append(clock.measure { workspace.cancelTransform() })
            #expect(workspace.transformDraft == nil && workspace.historySteps == before && !workspace.canRedo)
        }
        check("Free Transform escape", cancels)
    }

    private func canvasWithASquare() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: .live)
        try workspace.newCanvas(width: 6000, height: 4000)
        let bytes = [UInt8](repeating: 200, count: 600 * 600 * 4)
        workspace.paste(ClipboardImage(image: DecodedImage(rgba8: bytes, width: 600, height: 600),
                                       source: PixelRect(x: 0, y: 0, width: 600, height: 600)),
                        viewCenter: Mask.Point(x: 1500, y: 1300))
        return workspace
    }

    private func check(_ name: String, _ costs: [Duration]) {
        let sorted = costs.sorted()
        let p95 = sorted.isEmpty ? .zero : sorted[sorted.count * 95 / 100]
        print("PhotoBudget \(name) p50 \(sorted.isEmpty ? .zero : sorted[sorted.count / 2]) p95 \(p95) (\(sorted.count) events, \(gated ? "gated" : "report only"))")
        #expect(sorted.count == rounds, "\(name): \(sorted.count) samples, \(rounds) needed")
        if gated { #expect(p95 <= .milliseconds(8), "\(name): p95 \(p95) over the 8 ms frame") }
    }
}
