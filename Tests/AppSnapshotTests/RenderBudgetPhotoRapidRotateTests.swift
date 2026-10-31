// RenderBudgetPhotoRapidRotateTests.swift: many Free Transform rotations in a row on the real Photo window, on
// the CPU's tiles, on Metal, and on the GPU route drawing tiles (no Metal presenter), then Return. 30 knob drags, each turning the other way from the last and held until
// the layer rides the canvas's live layer, either waiting for the release's exact picture or pressing again at
// once (so the next drag starts before the last drop's picture is presented). Return must apply (a 10 s hang
// guard; the time is printed) and lay exactly one commit of the final transform (the same draft committed on a
// fresh copy). The window's own work must stay flat: one set of live-layer pixels for the whole Free Transform,
// made when its draft first shows (its pixels never change while the draft is up) and none by the drags, at most
// one lift per drag, and wherever pictures come back as tiles one picture's tiles per drag at most. A second Photo window drawing
// alongside (as CI's parallel suites do) must not count: every count is the window's renderer's, and the process's
// footprint and GPU-resident bytes are only printed. Nested in BodyCountSuites. macOS only.
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

        /// Where the window draws: the CPU's tiles; the GPU into the Metal presenter's texture (the app on a Mac);
        /// or the GPU route with the view on its tile layers, so each render reads its tiles back (a runner whose
        /// Metal presenter isn't up, as CI's was in run 40605553090).
        enum Route: String, CaseIterable, CustomTestStringConvertible, Sendable {
            case tiles, metal, gpuTiles
            var choice: RenderingChoice { self == .tiles ? .cpu : .gpu }
            var testDescription: String { rawValue }
        }

        @Test(.timeLimit(.minutes(6)), arguments: Route.allCases, [false, true])
        func rapidRotationsThenReturnApplyOneCommit(_ route: Route, backToBack: Bool) async throws {
            let choice = route.choice
            var model = try PhotoWorkspace.fixture(ProcessInfo.processInfo.environment["RAPID_LARGE"] == nil ? .sample : .large)
            model.selectTool(.select)
            try model.beginTransform()
            let fixture = model
            // Another Photo window drawing alongside, as the suites running in parallel on CI do: none of its work
            // may count as this window's.
            let neighbor = RenderBudgetWindow(PhotoWindow(model: try PhotoWorkspace.fixture(.layered)), underTest: false)
            defer { neighbor.close() }
            // One GPU backend, the window's and the one whose resident bytes the readings take.
            let gpu = try #require(ImagingGPU.systemBackend(), "no GPU")
            let rendering = PhotoRendering(preference: FakeRenderingPreference(choice: choice), makeGPU: { gpu.renderBackend })
            let w = RenderBudgetWindow(AnyView(PhotoWindow(model: model).allowsWindowActivationEvents()
                .environment(\.photoRendering, rendering)))
            defer { w.close() }
            // RAPID_ONSCREEN (a manual run only) puts the window on the main screen, so the window server composites it.
            if ProcessInfo.processInfo.environment["RAPID_ONSCREEN"] != nil, let screen = NSScreen.main {
                w.window.setFrameOrigin(NSPoint(x: screen.visibleFrame.minX + 40, y: screen.visibleFrame.minY + 40))
            }
            let edited = try await RenderBudgetPhotoTransformTests.settle(w)
            let renderer = try await Self.renderer(of: w)
            if route == .gpuTiles {
                // The view leaves Metal for its tile layers while the renderer stays on the GPU: no presenter texture.
                let host = try #require(RenderBudgetPhotoLiveTransformTests.canvas(in: w.host))
                host.useRendering(.cpu, device: nil, presenter: ClearingMetalPresenter())
            }
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
            let send = try #require(edited.send)
            // The draft's first show makes the live layer's pixels, once.
            for _ in 0..<500 where renderer.spritesMade == 0 { try await Task.sleep(for: .milliseconds(20)) }
            #expect(renderer.spritesMade == 1, "\(route): Free Transform's first show made \(renderer.spritesMade) live-layer pixel sets")
            let start = Self.reading(gpu, renderer)
            var readings: [Reading] = []
            for drag in 0..<Self.drags {
                try await Self.turn(w, degrees: drag.isMultiple(of: 2) ? 30 : -25)
                if !backToBack { try await RenderBudgetPhotoLiveTransformTests.idle(w) }
                readings.append(Self.reading(gpu, renderer))
            }
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
            let end = Self.reading(gpu, renderer)
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
            // draft: one set for the whole Free Transform, on every route.
            #expect(grew.sprites == 0, "\(route): the drags made \(grew.sprites) live-layer pixel sets")
            // On the tile path a drag draws one picture, its release's exact one: a layer with nothing under it
            // hides the picture rather than drawing an empty one. (Metal draws into its texture: no tile surfaces.)
            let canvas = try #require(fixture.canvas)
            let tilesPerPicture = ((canvas.width + 255) / 256) * ((canvas.height + 255) / 256)
            #expect(grew.surfaces <= Self.drags * tilesPerPicture,
                    "\(route): \(grew.surfaces) tile surfaces over \(Self.drags) drags, more than one picture (\(tilesPerPicture) tiles) a drag")
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
            #expect(RenderBudgetPhotoLiveTransformTests.canvas(in: w.host)?.hasLiveLayer == true, "a drag never showed the live layer")
            w.send(.leftMouseUp, at: drag.point(12))
        }

        /// The window's own renderer (other windows' work never counts here).
        static func renderer<V: View>(of w: RenderBudgetWindow<V>) async throws -> CanvasRenderer {
            for _ in 0..<100 {
                if let host = RenderBudgetPhotoLiveTransformTests.canvas(in: w.host), let found = CanvasRenderer.rendering(into: host) {
                    return found
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            throw RenderBudgetPhotoLiveTransformTests.NoRenderer()
        }

        /// What the drags have cost the window so far; the footprint and GPU-resident bytes are the process's and
        /// only printed (suites running alongside move them).
        struct Reading: CustomStringConvertible {
            var footprint = 0, resident = 0, sprites = 0, surfaces = 0, lifts = 0
            func since(_ s: Reading) -> Reading {
                Reading(footprint: footprint - s.footprint, resident: resident - s.resident, sprites: sprites - s.sprites,
                        surfaces: surfaces - s.surfaces, lifts: lifts - s.lifts)
            }
            var description: String {
                "footprint \(footprint / 1_000_000) MB, GPU resident \(resident / 1_000_000) MB, \(sprites) live-layer pixel sets, \(surfaces) tile surfaces, \(lifts) lifts"
            }
        }

        static func reading(_ gpu: ImagingGPU.Backend, _ renderer: CanvasRenderer) -> Reading {
            let metal = gpu.renderBackend as? MetalBackend
            return Reading(footprint: footprint(), resident: metal?.residentBytes ?? 0, sprites: renderer.spritesMade,
                           surfaces: renderer.tiles.surfacesHanded, lifts: renderer.liftsRun)
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
