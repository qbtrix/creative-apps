// RenderBudgetPhotoRapidRotateTests.swift: many Free Transform rotations in a row on the real Photo window on
// Metal (the app's route), then Return. 30 knob drags, each turning the other way from the last and held until
// the layer rides the canvas's live layer, either waiting for the release's exact picture or pressing again at
// once (so the next drag starts before the last drop's picture is presented). Return must apply (a 10 s hang
// guard; the time is printed), the layer must be exactly one commit of the final transform (the same draft committed on a fresh copy),
// and the gesture's memory must stay flat: one live-layer surface for the whole Free Transform, made when its
// draft first shows (its pixels never change while the draft is up) and none by the drags, at most one lift per drag, and no growth in GPU-resident bytes or the process
// footprint that scales with the number of drags. Nested in
// BodyCountSuites: it reads process-wide counters. macOS only.
#if canImport(AppKit)
import AppKit
import CoreRenderMetal
import PhotoModel
import SuiteImaging
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoRapidRotateTests {
        static let drags = 30

        @Test(.timeLimit(.minutes(6)), arguments: [false, true])
        func rapidRotationsThenReturnApplyOneCommit(backToBack: Bool) async throws {
            var model = try PhotoWorkspace.fixture(ProcessInfo.processInfo.environment["RAPID_LARGE"] == nil ? .sample : .large)
            model.selectTool(.move)
            try model.beginTransform()
            let fixture = model
            let opened = CanvasTile.surfacesMade
            // One GPU backend, the window's and the one whose resident bytes the readings take.
            let gpu = try #require(ImagingGPU.systemBackend(), "no GPU")
            let rendering = PhotoRendering(preference: FakeRenderingPreference(choice: .gpu), makeGPU: { gpu.renderBackend })
            let w = RenderBudgetWindow(AnyView(PhotoWindow(model: model).allowsWindowActivationEvents()
                .environment(\.photoRendering, rendering)))
            defer { w.close() }
            // RAPID_ONSCREEN (a manual run only) puts the window on the main screen, so the window server composites it.
            if ProcessInfo.processInfo.environment["RAPID_ONSCREEN"] != nil, let screen = NSScreen.main {
                w.window.setFrameOrigin(NSPoint(x: screen.visibleFrame.minX + 40, y: screen.visibleFrame.minY + 40))
            }
            let edited = try await RenderBudgetPhotoTransformTests.settle(w)
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
            let send = try #require(edited.send)
            // The draft's first show makes the live layer's pixels (on Metal no tile makes a surface).
            for _ in 0..<500 where CanvasTile.surfacesMade == opened { try await Task.sleep(for: .milliseconds(20)) }
            #expect(CanvasTile.surfacesMade - opened == 1, "Free Transform's first show made \(CanvasTile.surfacesMade - opened) live-layer surfaces")
            let start = Self.reading(gpu)
            #expect(start.resident > 0, "the picture never went resident: the window isn't on the app's GPU route")
            var readings: [Reading] = []
            for drag in 0..<Self.drags {
                try await Self.turn(w, degrees: drag.isMultiple(of: 2) ? 30 : -25)
                if !backToBack { try await RenderBudgetPhotoLiveTransformTests.idle(w) }
                readings.append(Self.reading(gpu))
            }
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
            let end = Self.reading(gpu)
            for (i, r) in readings.enumerated() where i % 5 == 4 { print("RENDER-BUDGET photo rapid rotate \(backToBack ? "back to back" : "settled"), drag \(i + 1): \(r.since(start))") }
            // The last release hands the copy back: that draft is what Return lays.
            let final = try #require(await RenderBudgetPhotoTransformTests.landed(edited) { _ in false }?.transformSelection)
            let clock = ContinuousClock(), returned = clock.now
            send(.confirm)
            var applied: PhotoWorkspace?
            for _ in 0..<1000 {
                if let shown = edited.workspace, shown.transformDraft == nil { applied = shown; break }
                try await Task.sleep(for: .milliseconds(10))
            }
            let took = clock.now - returned
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
            print("RENDER-BUDGET photo rapid rotate \(backToBack ? "back to back" : "settled"): Return applied in \(took); over \(Self.drags) drags \(end.since(start))")
            // not-timing: the 10 s wait is a hang guard (a stuck main thread never applies); the time is printed.
            let done = try #require(applied, "Return didn't apply after the rotations (\(took))")
            let grew = end.since(start)
            #expect(grew.lifts <= Self.drags, "\(grew.lifts) lifts for \(Self.drags) drags")
            // The lifted pixels are the untransformed layer in the draft's box, the same for every drag of one
            // draft: one surface for the whole Free Transform, not one per drag.
            #expect(grew.surfaces == 0, "\(grew.surfaces) live-layer surfaces for \(grew.lifts) lifts")
            // Memory that grows with the drags: compare the last ten drags with the ten before them.
            let (a, b) = (readings[Self.drags - 11].since(start), readings[Self.drags - 1].since(start))
            #expect(b.resident - a.resident <= 8_000_000, "GPU-resident bytes grew \(b.resident - a.resident) over the last 10 drags")
            #expect(b.footprint - a.footprint <= 64_000_000, "the footprint grew \(b.footprint - a.footprint) over the last 10 drags")
            var reference = fixture
            try reference.setTransform(final, name: "Rotate", drag: nil)
            try reference.commitTransform()
            let id = try #require(done.selectedLayerID)
            #expect(done.pixels[id] == reference.pixels[id], "the applied layer isn't one commit of the final transform \(final)")
        }

        /// One knob drag turning `degrees` round the box's centre over 12 samples at 120 Hz, held until the layer
        /// rides the live layer (up to 2 s), then released.
        static func turn<V: View>(_ w: RenderBudgetWindow<V>, degrees: Double) async throws {
            let box = try #require(w.elementNow("photo.canvas.transform-box"), "no transform box")
            let knob = try #require(w.elementNow("suite.handles.turn"), "no rotate knob")
            let start = CGPoint(x: knob.midX, y: knob.midY)
            try #require(w.host.bounds.insetBy(dx: 40, dy: 40).contains(start), "the knob left the canvas: \(start)")
            let drag = RenderBudgetPhotoLiveTransformTests.RotateDrag(
                start: start, centre: CGPoint(x: box.midX, y: box.midY), degrees: degrees, samples: 12)
            w.send(.leftMouseDown, at: drag.start)
            try await w.ticks(12) { w.send(.leftMouseDragged, at: drag.point($0)) }
            for _ in 0..<100 where RenderBudgetPhotoLiveTransformTests.canvas(in: w.host)?.hasLiveLayer != true {
                try await Task.sleep(for: .milliseconds(20))
            }
            w.send(.leftMouseUp, at: drag.point(12))
        }

        /// What the drags have cost so far.
        struct Reading: CustomStringConvertible {
            var footprint = 0, resident = 0, surfaces = 0, lifts = 0, pictures = 0
            func since(_ s: Reading) -> Reading {
                Reading(footprint: footprint - s.footprint, resident: resident - s.resident, surfaces: surfaces - s.surfaces,
                        lifts: lifts - s.lifts, pictures: pictures - s.pictures)
            }
            var description: String {
                "footprint \(footprint / 1_000_000) MB, GPU resident \(resident / 1_000_000) MB, \(surfaces) surfaces, \(lifts) lifts, \(pictures) pictures"
            }
        }

        static func reading(_ gpu: ImagingGPU.Backend) -> Reading {
            let metal = gpu.renderBackend as? MetalBackend
            return Reading(footprint: footprint(), resident: metal?.residentBytes ?? 0, surfaces: CanvasTile.surfacesMade,
                           lifts: CanvasRenderer.lifts, pictures: CanvasRenderer.pictures)
        }

        /// The process's physical footprint in bytes.
        static func footprint() -> Int {
            var info = task_vm_info_data_t()
            var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
            }
            return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
        }
    }
}
#endif
