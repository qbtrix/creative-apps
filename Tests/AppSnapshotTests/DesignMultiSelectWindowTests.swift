// DesignMultiSelectWindowTests.swift: a click on one of several selected layers, in the real window
// (#5838, journey J9). Two of three rectangles selected, a mouse-down and mouse-up on the first one
// through the canvas leaves it selected alone, so a later ⌘-click makes two layers, not three. It
// reads DesignWindow.lastWorkspace, a static, so it nests in BodyCountSuites. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignMultiSelectWindowTests {
        @Test(.timeLimit(.minutes(2))) func aClickOnOneOfTwoSelectedPicksItAlone() async throws {
            #if DEBUG
            var seed = DesignWorkspace()
            seed.newFile()
            for x in [100.0, 400, 700] {
                seed.selectTool(.rectangle)
                seed.drag(from: DesignPoint(x: x, y: 100), to: DesignPoint(x: x + 200, y: 300))
                seed.endDrag()
            }
            seed.deselect()
            seed.toggleSelection("node-2")
            seed.toggleSelection("node-3")
            #expect(seed.selectedNodeIDs == ["node-2", "node-3"])
            let page = try #require(seed.selectedPage)
            let w = RenderBudgetWindow(DesignWindow(seed: seed))
            defer { w.close() }
            try await w.settle(800)
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            let size = CGSize(width: page.frameWidth, height: page.frameHeight)
            w.click(at: w.point(CGPoint(x: 150, y: 150), on: size, in: board))
            try await w.settle(200)
            let after = try #require(DesignWindow.lastWorkspace, "the click never reached the window")
            #expect(after.selectedNodeIDs == ["node-2"], "the click kept \(after.selectedNodeIDs)")
            #expect(after.selectionBounds == DesignRect(x: 100, y: 100, width: 200, height: 200), "the click moved the layer")
            #endif
        }
    }
}
#endif
