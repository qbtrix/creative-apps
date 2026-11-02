// RenderBudgetEyedropperTests.swift (eyedropper EY-4): the loupe's render budget (RenderBudgetHarness.swift). A
// pointer model moves a SampleLoupe over red, green and black swatches 120 times, one per 120 Hz tick; only the
// loupe's layer reads it, so the page body runs at most 3 times. `loupeTrackTiming` is report-only (perf-suites).
// Nested in BodyCountSuites: it reads a global counter. macOS only.
#if canImport(AppKit)
import AppKit
import Observation
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetEyedropperTests {
        @Test(.timeLimit(.minutes(2))) func loupeTrackInThreeBodies() async throws {
            let (track, moves) = try await Self.run()
            #expect(moves == 120, "the loupe moved \(moves) of 120 times")
            // The pointer is read only by the loupe's layer: the page's body never runs. Budget 3, target 0.
            expectBodies(track, atMost: 3, target: 0)
        }

        @Test(.timeLimit(.minutes(2))) func loupeTrackTiming() async throws {
            let (track, _) = try await Self.run()
            // Target: a pointer move fits one 120 Hz frame.
            expectP95(track, atMost: 8, target: 4)
        }

        static func run() async throws -> (track: RenderStep, moves: Int) {
            let pointer = LoupePointer()
            let w = RenderBudgetWindow(LoupeBudgetPage(pointer: pointer))
            defer { w.close() }
            let bodies = { () -> Int? in LoupeBudgetPage.bodyRuns }
            try await w.settle(untilStable: bodies)
            let side = LoupeBudgetPage.side
            let track = try await w.measure("eyedropper loupe track, 120 samples", bodies: bodies) {
                try await w.ticks(120) { i in
                    let x = side * 3 * Double(i) / 120
                    let swatch = min(Int(x / side), LoupeBudgetPage.colors.count - 1)
                    pointer.move(to: CGPoint(x: x, y: side / 2), color: LoupeBudgetPage.colors[swatch])
                }
            }
            return (track, pointer.moves)
        }
    }
}

/// What an eyedropper tool's hover hands the loupe: the point and the colour under it.
@MainActor @Observable private final class LoupePointer {
    private(set) var point = CGPoint.zero
    private(set) var color: HexColor?
    @ObservationIgnored private(set) var moves = 0

    func move(to point: CGPoint, color: HexColor?) {
        self.point = point
        self.color = color
        moves += 1
    }
}

/// The canvas and its loupe layer; the page's body is the window body the budget counts.
private struct LoupeBudgetPage: View, BodyCounted {
    @Environment(\.bodyTally) private var bodyTally
    static let side = SuiteSize.toolButton * 4
    static let colors = [HexColor(255, 0, 0), HexColor(0, 255, 0), HexColor.black]
    let pointer: LoupePointer

    var body: some View {
        let _ = bodyTally.ran(Self.self)
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(Self.colors, id: \.self) { Rectangle().fill($0.color) }
            }
            .frame(width: Self.side * 3, height: Self.side)
            LoupeLayer(pointer: pointer)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The only view that reads the pointer.
private struct LoupeLayer: View {
    let pointer: LoupePointer

    var body: some View {
        SampleLoupe(color: pointer.color, at: pointer.point)
    }
}
#endif
