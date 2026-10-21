// HaloViewerHandlesTests.swift: a handle drag in Halo's viewer (transform
// HT-3). HaloViewerHandles keeps one HaloHandleDrag per drag: each sample's
// step is shown through the window's HaloLiveEdit, the release hands the last
// step to the window once, and Escape drops it. The tests drive that value on
// `keyed` (fake services) with Ball selected at frame 12: a corner drag
// previews every sample and commits one "Scale" on release; the knob turns
// the box by the turn so far from the press, never compounding; Escape leaves
// nothing to commit. On the HT-1 stubs `setTransform` refuses, so they check
// what is shown and handed over, not the Model's change. macOS only.
import HaloModel
import SuiteKernel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloViewerHandlesTests {
    /// `keyed` with Ball selected at frame 12, and Ball's box there.
    static func ball() throws -> (HaloProject, TransformBox) {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" }).id
        project.selectLayer(ball)
        project.scrub(to: 12)
        return (project, try #require(project.transformSelection))
    }

    @Test func aCornerDragPreviewsEachSampleAndCommitsOnceOnRelease() throws {
        let (project, item) = try Self.ball()
        let live = HaloLiveEdit()
        live.current = { project }
        var drag = HaloHandleDrag()
        var commits: [HaloHandleStep] = []
        var last = HaloViewerHandles.rect(item)
        for i in 1...12 {
            last = CGRect(x: last.minX, y: last.minY, width: HaloViewerHandles.rect(item).width + Double(i) * 4,
                          height: HaloViewerHandles.rect(item).height + Double(i) * 2)
            HaloHandleDrag.show(drag.resized(last, from: item), in: live)
            #expect(live.project != nil, "sample \(i) wasn't shown live")
            #expect(commits.isEmpty, "the drag committed at sample \(i)")
        }
        if let step = drag.end() { commits.append(step) }
        live.project = nil
        #expect(commits.count == 1)
        let step = try #require(commits.first)
        #expect(step.name == "Scale")
        #expect(HaloViewerHandles.rect(step.box) == last)
        #expect(step.box.degrees == item.degrees)
        #expect(drag.end() == nil, "a second release committed again")
        #expect(drag.start == nil)
    }

    @Test func theKnobTurnsTheBoxByTheTurnSoFarFromThePress() throws {
        let (_, item) = try Self.ball()
        var drag = HaloHandleDrag()
        // `turned` is mutating, so it runs outside the macro, which takes its receiver immutably.
        let turnedOnce = drag.turned(10, from: item)
        let first = try #require(turnedOnce)
        // The handles redraw on the preview's turned box; the turn stays relative to the press.
        let turnedTwice = drag.turned(30, from: first.box)
        let second = try #require(turnedTwice)
        #expect(second.name == "Rotate")
        #expect(second.box.degrees == TransformRules.normalized(item.degrees + 30))
        #expect(second.box.box == item.box, "the turn moved the box off its centre")
        #expect(drag.end() == second)
    }

    @Test func escapeLeavesNothingToCommit() throws {
        let (project, item) = try Self.ball()
        let live = HaloLiveEdit()
        live.current = { project }
        var drag = HaloHandleDrag()
        HaloHandleDrag.show(drag.resized(HaloViewerHandles.rect(item).insetBy(dx: -20, dy: -20), from: item), in: live)
        drag.cancel()
        live.project = nil
        // The mouse is still down: later samples show nothing until the release.
        #expect(drag.turned(45, from: item) == nil)
        #expect(drag.end() == nil)
        #expect(live.project == nil)
        // The next drag starts clean.
        #expect(drag.turned(15, from: item) != nil)
    }

    @Test func aClickOrAnIdleEscapeCommitsNothing() throws {
        let (_, item) = try Self.ball()
        var drag = HaloHandleDrag()
        drag.cancel()
        #expect(drag.end() == nil)
        #expect(drag.resized(HaloViewerHandles.rect(item), from: item) != nil, "an idle Escape cancelled the next drag")
        #expect(drag.resized(CGRect(x: 0, y: 0, width: 0, height: 10), from: item) != nil)
        #expect(drag.end()?.box.box.width ?? 0 >= 1, "a box below 1 pixel was committed")
    }
}
