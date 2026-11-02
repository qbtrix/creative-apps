// LiveTransformCopyTests.swift (#4795): Photo's live transform waits for the quiet hand-back only while
// nothing holds it. A handle drag's `hold()` drops the waiting hand-back and keeps any later sample from
// starting one, so a pointer that rests mid-drag keeps the copy until `take()` (its mouse-up). `take()`
// lets go, so the next row scrub settles on quiet again. Reads `settling`, no clock. macOS only.
import PhotoModel
import Testing

@testable import PhotoApp

@MainActor @Suite struct LiveTransformCopyTests {
    @Test func aRowScrubSampleWaitsForQuiet() {
        let live = LiveTransformCopy()
        _ = live.run(on: PhotoWorkspace(), done: {}) { _ in }
        #expect(live.settling)
    }

    @Test func aHeldDragNeverWaitsForQuiet() {
        let live = LiveTransformCopy()
        _ = live.run(on: PhotoWorkspace(), done: {}) { _ in }
        live.hold()
        #expect(!live.settling, "hold() left the first sample's quiet hand-back waiting")
        _ = live.run(on: PhotoWorkspace(), done: {}) { _ in }
        #expect(!live.settling, "a held sample started a quiet hand-back")
        #expect(live.take() != nil)
    }

    @Test func takeLetsGo() {
        let live = LiveTransformCopy()
        live.hold()
        _ = live.run(on: PhotoWorkspace(), done: {}) { _ in }
        _ = live.take()
        #expect(!live.held)
        _ = live.run(on: PhotoWorkspace(), done: {}) { _ in }
        #expect(live.settling, "after take() a row scrub's sample didn't wait for quiet")
    }
}
