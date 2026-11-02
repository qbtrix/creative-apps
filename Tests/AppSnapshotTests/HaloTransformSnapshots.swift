// HaloTransformSnapshots.swift: Halo's viewer handles while transforming
// (transform HT-4), on `keyed` (fake services) at frame 12 with Ball
// selected. `turned`: Ball's rotation set to 30°, the layer and its handles
// drawn turned, with no upright outline of its own under them. `scaling`: a
// handle drag mid-way, the window's HaloLiveEdit showing Ball at 1.5 × while the Model still holds 1 ×, so the
// handles follow the preview, not the Model. Light and Dark. Writes
// halo-viewer-handles-turned-*.png and halo-viewer-handles-scaling-*.png.
// macOS only.
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloTransformSnapshots {
    @Test func turnedThirtyDegrees() throws {
        var (project, _) = try HaloViewerHandlesTests.ball()
        project.setProperty(.rotation, to: 30)
        project.endPropertyScrub()
        #expect(project.transformSelection != nil)
        // The handles draw Ball's turned box; a dashed upright outline under them read as a second selection.
        #expect(HaloLiveLayers.outlinedLayer(project) == nil, "the canvas outlines Ball under its handles")
        try snapshot(HaloViewer(model: project), name: "halo-viewer-handles-turned-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-viewer-handles-turned-dark", scheme: .dark)
    }

    @Test func scalingShowsTheLivePreview() throws {
        let (project, item) = try HaloViewerHandlesTests.ball()
        var scaled = project
        scaled.setProperty(.scaleX, to: 1.5)
        scaled.setProperty(.scaleY, to: 1.5)
        scaled.endPropertyScrub()
        let preview = try #require(scaled.transformSelection)
        #expect(preview.box.width > item.box.width, "Ball didn't grow: \(item.box) → \(preview.box)")
        let live = HaloLiveEdit()
        live.project = scaled
        let view = HaloViewer(model: project).environment(\.haloLiveEdit, live)
        try snapshot(view, name: "halo-viewer-handles-scaling-light", scheme: .light)
        try snapshot(view, name: "halo-viewer-handles-scaling-dark", scheme: .dark)
    }
}
