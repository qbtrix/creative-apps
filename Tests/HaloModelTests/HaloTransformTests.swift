// HaloTransformTests.swift: transform HT-1 and HT-5. HaloProject as a
// SuiteKernel TransformTarget. On the stubs (HT-1) nothing selected says why,
// Flip says it isn't in Halo yet and the selected layer reads its drawn box.
// HT-5: a turn at 12 on an animated Rotation keys 12, on a static one sets
// the value, a scale about the centre keeps the centre and a 120-sample drag
// is one step, and mid viewer drag the box moves with the layer. On
// `-HaloFixture keyed` Ball. Linux and macOS.
import FlareCore
@testable import HaloModel
import SuiteKernel
import Testing

/// `keyed` with Ball selected and the playhead at `frame`.
private func ballProject(at frame: Int = 12) throws -> HaloProject {
    let state = try #require(HaloFixtures.project("keyed"))
    var project = HaloProject(services: .fake)
    project.restore(state)
    let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" })
    project.selectLayer(ball.id)
    project.scrub(to: frame)
    return project
}

private func row(_ p: HaloProperty, in project: HaloProject) -> HaloPropertyRow? {
    project.propertyRows.first { $0.property == p }
}

private func centre(_ t: TransformBox) -> (Double, Double) {
    ((t.box.minX + t.box.maxX) / 2, (t.box.minY + t.box.maxY) / 2)
}

@Suite struct HaloTransformTests {
    /// Flip is refused with the same sentence whatever is selected.
    @Test func flipSaysItIsNotInHaloYet() throws {
        #expect(HaloProject(services: .fake).flipHelp == "Flipping isn't in Halo yet.")
        #expect(try ballProject().flipHelp == "Flipping isn't in Halo yet.")
    }

    /// With no layer selected there is no box and the help says what to do.
    @Test func nothingSelectedSaysWhy() throws {
        let project = HaloProject(services: .fake)
        #expect(project.selectedLayer == nil)
        #expect(project.transformSelection == nil)
        #expect(project.transformHelp == "Select a layer to transform.")
    }

    /// The selected layer's box is where the viewer draws it, unturned.
    @Test func selectedLayerReadsItsDrawnBox() throws {
        let project = try ballProject()
        let item = try #require(project.transformSelection)
        let id = try #require(project.selectedLayerID)
        let drawn = try #require(project.viewerDrawList?.worldBox(of: id))
        #expect(item.box == Rect(minX: drawn.x, minY: drawn.y, maxX: drawn.x + drawn.width, maxY: drawn.y + drawn.height))
        #expect(item.degrees == 0 && !item.flipX && !item.flipY)
        #expect(project.transformHelp == nil)
    }

    @Test func aTurnOnAnimatedRotationKeysThisFrame() throws {
        var project = try ballProject(at: 0)
        project.toggleAnimation(.rotation)
        project.scrub(to: 12)
        let item = try #require(project.transformSelection)
        try project.setTransform(TransformRules.rotated(item, by: 30), name: "Rotate", drag: nil)
        #expect(row(.rotation, in: project)?.keyState == .keyedHere)
        #expect(project.transformSelection?.degrees == 30)
        #expect(project.history.undoTitle == "Undo Rotate")
    }

    @Test func aTurnOnStaticRotationSetsTheValue() throws {
        var project = try ballProject()
        let item = try #require(project.transformSelection)
        try project.setTransform(TransformRules.rotated(item, by: 30), name: "Rotate", drag: nil)
        #expect(row(.rotation, in: project)?.keyState == .notAnimated)
        #expect(row(.rotation, in: project)?.value == 30)
        #expect(project.history.undo.count == 1)
    }

    @Test func aScaleAboutTheCentreKeepsTheCentre() throws {
        var project = try ballProject()
        let item = try #require(project.transformSelection)
        try project.setTransform(TransformRules.scaled(item, sx: 2, sy: 2, about: .center), name: "Scale", drag: nil)
        let after = try #require(project.transformSelection)
        let (bx, by) = centre(item), (ax, ay) = centre(after)
        #expect(abs(ax - bx) < 1e-6 && abs(ay - by) < 1e-6)
        #expect(abs(after.box.width - item.box.width * 2) < 1e-6)
        #expect(row(.scaleX, in: project)?.value == row(.scaleY, in: project)?.value)
    }

    @Test func dragIsOneStep() throws {
        var project = try ballProject()
        let start = try #require(project.transformSelection)
        for n in 1...120 {
            try project.setTransform(TransformRules.rotated(start, by: Double(n) * 0.5), name: "Rotate", drag: "turn-1")
        }
        #expect(project.history.undo.count == 1)
        #expect(abs((project.transformSelection?.degrees ?? 0) - 60) < 1e-6)
    }

    /// Mid viewer drag the box moves with the dragged layer's preview, so the
    /// handles follow it; mouse-up leaves it where the layer landed.
    @Test func theBoxFollowsAViewerDrag() throws {
        var project = try ballProject()
        let rest = try #require(project.transformSelection)
        let (cx, cy) = centre(rest)
        project.beginViewerDrag(at: HaloPoint(x: cx, y: cy))
        project.moveViewerDrag(to: HaloPoint(x: cx + 100, y: cy - 30))
        let moving = try #require(project.transformSelection)
        #expect(abs(centre(moving).0 - (cx + 100)) < 1e-6 && abs(centre(moving).1 - (cy - 30)) < 1e-6)
        #expect(moving.degrees == rest.degrees)
        project.endViewerDrag()
        let landed = try #require(project.transformSelection)
        #expect(abs(centre(landed).0 - (cx + 100)) < 1e-6 && abs(centre(landed).1 - (cy - 30)) < 1e-6)
    }
}
