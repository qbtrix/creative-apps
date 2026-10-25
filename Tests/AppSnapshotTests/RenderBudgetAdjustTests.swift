// RenderBudgetAdjustTests.swift (adjust-everywhere AJ-4): a 120-sample
// pointer hover across Photo's Looks grid (PhotoLooks: the six built-ins and
// one saved look in an open workspace's fake store) runs the counted window's body at most twice
// (target 0: only the hovered buttons redraw). Beside it, the screens
// photo-adjust-looks-{light,dark}.png: the grid with one saved look. Nested
// in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import Foundation
import PhotoModel
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

/// An open 1 px image whose look store holds one saved look, "Evening".
@MainActor private func lookTarget() throws -> PhotoWorkspace {
    let evening = LookPreset(id: "evening", name: "Evening", kinds: [.invert])
    let record = PresetRecord(id: evening.id, name: evening.name, kind: LookPreset.recordKind,
                              payload: try JSONEncoder().encode(evening))
    var services = PhotoServices.fake
    services.looks = FakePresetStore([record])
    var ws = PhotoWorkspace(services: services)
    try ws.open(rgba8: [128, 128, 128, 255], width: 1, height: 1, name: "grey.png")
    return ws
}

/// The counted window: Photo's Looks section at the inspector's width, in a panel.
private struct LooksBudgetWindow: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif
    let target: PhotoWorkspace

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        PhotoLooks(model: target, perform: { _ in })
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
