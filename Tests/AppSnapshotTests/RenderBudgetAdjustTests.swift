// RenderBudgetAdjustTests.swift (adjust-everywhere AJ-4): a 120-sample
// pointer hover across Photo's Looks grid (PhotoLooks: the six built-ins and
// one saved look on a fake store) runs the counted window's body at most twice
// (target 0: only the hovered buttons redraw). Beside it, the screens
// photo-adjust-looks-{light,dark}.png: the grid with one saved look. Nested
// in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import Foundation
import SuiteImaging
import SuiteModel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetAdjustTests {
        @Test(.timeLimit(.minutes(2))) func lookHoverInTwoBodies() async throws {
            let w = RenderBudgetWindow(LooksBudgetWindow(target: try lookTarget()))
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return LooksBudgetWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            let first = try #require(await w.element("suite.looks.look.bw"), "the grid shows no B&W look")
            let last = try #require(await w.element("suite.looks.look.evening"), "the grid shows no saved look")
            let hover = try await w.measure("photo looks hover across the grid, 120 samples", bodies: bodies) {
                try await w.ticks(120) { i in
                    let t = Double(i) / 120
                    w.send(.mouseMoved, at: CGPoint(x: first.midX + (last.midX - first.midX) * t,
                                                   y: first.midY + (last.midY - first.midY) * t))
                }
            }
            expectBodies(hover, atMost: 2, target: 0)
        }
    }
}

/// The stub target with one saved look, "Evening", in its store.
@MainActor private func lookTarget() throws -> PendingAdjustTarget {
    let evening = LookPreset(id: "evening", name: "Evening", kinds: [.invert])
    let record = PresetRecord(id: evening.id, name: evening.name, kind: LookPreset.recordKind,
                              payload: try JSONEncoder().encode(evening))
    return PendingAdjustTarget(looks: FakePresetStore([record]))
}

/// The counted window: Photo's Looks section at the inspector's width, in a panel.
private struct LooksBudgetWindow: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif
    let target: PendingAdjustTarget

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        PhotoLooks(target: target)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
            .background(SuiteColor.panel)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}

@MainActor @Suite struct PhotoLooksSnapshots {
    @Test func screens() throws {
        let target = try lookTarget()
        #expect(LookGridRows(target.looks).looks.map(\.id) == BuiltInLooks.all.map(\.id) + ["evening"])
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(LooksBudgetWindow(target: target), name: "photo-adjust-looks-\(scheme.name)", scheme: scheme)
        }
    }
}
#endif
