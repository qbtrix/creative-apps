// HaloCoreLoopTests.swift: MJ-CL1 (core-loop CL-1, #1971). The Linux walk of
// the whole core loop on the live services, one person in one sitting: a new
// composition, a solid, a Position X key, a viewer drag that keys frame 24,
// Ease Out on the first key, Play, a text layer, Undo and Redo, then the file
// round trip. `walkRenders` adds File > Render… through the kernel adapter
// (HaloRenderJob+Kernel), on since CL-6. The live set has no rasterizer
// until HaloApp sets one, so `services.text` is the fake's. Linux and macOS.
@testable import HaloModel
import Testing

@Suite struct HaloCoreLoopTests {
    /// The live services with the fake rasterizer.
    private static var services: HaloServices {
        var live = HaloServices.live
        live.text = FakeTextRasterizer()
        return live
    }

    /// "Loop", 24 fps, 2 s on the live services: 48 frames.
    private static func loop() throws -> HaloProject {
        var project = HaloProject(services: services)
        let made = project.newComposition(CompositionSettings(name: "Loop", framesPerSecond: 24, durationSeconds: 2))
        #expect(made)
        #expect(try #require(project.selectedComposition).durationFrames == 48)
        return project
    }

    private static func solid(_ project: HaloProject) throws -> HaloLayer {
        try #require(project.selectedComposition?.layers.first { $0.kind == .solid })
    }

    /// The solid's box centre in composition pixels at the playhead.
    private static func centre(_ project: HaloProject) throws -> HaloPoint {
        let comp = try #require(project.selectedComposition)
        let layer = try solid(project)
        let world = try #require(HaloKeyRules.worldMatrix(of: layer.id, in: comp, at: comp.playheadFrame))
        let b = layer.bounds(in: comp)
        return world.apply(HaloPoint(x: b.x + b.width / 2, y: b.y + b.height / 2))
    }

    private static func xFrames(_ project: HaloProject) throws -> [Int] {
        try (solid(project).tracks[HaloProperty.x.rawValue] ?? []).map(\.frame).sorted()
    }

    private static func x(_ project: HaloProject, at frame: Int) throws -> Double {
        let comp = try #require(project.selectedComposition)
        return HaloKeyRules.value(.x, of: try solid(project), in: comp, at: frame)
    }

    /// The walk up to a saved-ready document: every step but Render….
    private static func walked() throws -> HaloProject {
        var project = try loop()
        project.newLayer(.solid)
        let id = try solid(project).id
        #expect(project.selectedLayerID == id)

        project.toggleAnimation(.x)
        #expect(try xFrames(project) == [0, 47])
        #expect(project.undoTitle == "Undo Animate Position X")

        project.scrub(to: 24)
        let start = try x(project, at: 24), steps = project.history.undo.count
        let from = try centre(project)
        project.beginViewerDrag(at: from)
        project.moveViewerDrag(to: HaloPoint(x: from.x + 300, y: from.y))
        project.endViewerDrag()
        #expect(try xFrames(project) == [0, 24, 47])
        #expect(try x(project, at: 24) == start + 300)
        #expect(project.history.undo.count == steps + 1)
        #expect(project.undoTitle == "Undo Move")

        project.selectKey(HaloKeyRef(layerID: id, property: .x, frame: 0), extending: false)
        project.setEasing(.easeOut)
        let first = project.keySegments.first { $0.key.property == .x && $0.key.frame == 0 }
        #expect(first?.endFrame == 24 && first?.preset == .easeOut)
        #expect(project.undoTitle == "Undo Keyframe Easing")

        project.play(at: 0)
        _ = project.tick(now: 0.5)
        #expect((1...47).contains(try #require(project.selectedComposition).playheadFrame))
        project.pause()

        project.newLayer(.text)
        project.setText("Hello")
        #expect(project.undoTitle == "Undo Edit Text")
        let edited = project.document
        project.undo()
        #expect(project.document != edited)
        project.redo()
        #expect(project.document == edited)
        return project
    }

    /// The saved file reopens as the same document with no history.
    private static func expectRoundTrip(_ project: HaloProject) throws {
        let decoded = try project.services.files.decode(project.fileData())
        var reopened = HaloProject(services: services)
        reopened.restore(decoded)
        #expect(reopened.document.compositions == project.document.compositions)
        #expect(reopened.history.undo.isEmpty && reopened.undoTitle == nil)
    }

    @Test func walk() throws {
        let project = try Self.walked()
        try Self.expectRoundTrip(project)
    }

    @Test func walkRenders() throws {
        var project = try Self.walked()
        let begun = project.beginRender(HaloRenderSettings(format: .pngSequence, halfSize: true))
        #expect(begun)
        let result = project.startRender()
        let started = try #require(result)
        #expect(started.plan.frames.count == 48)
        #expect(started.plan.width == 960 && started.plan.height == 540)
        guard case .running(_, done: 0, total: 48) = project.renderRun else {
            Issue.record("not running: \(project.renderRun)")
            return
        }
        project.renderProgressed(done: 48)
        project.endRender(.finished(frames: 48))
        guard case .finished = project.renderRun else {
            Issue.record("not finished: \(project.renderRun)")
            return
        }
        project.dismissRender()
        #expect(project.renderRun == .idle)
        try Self.expectRoundTrip(project)
    }
}
