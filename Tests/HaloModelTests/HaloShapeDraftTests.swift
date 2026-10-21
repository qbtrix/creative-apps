// HaloShapeDraftTests.swift: shape-tools HS-3, the viewer drag's Model half:
// the draft, one shape per release, Escape, and `drawShape`'s refusal.
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloShapeDraftTests {
    static let star = ShapeSpec(kind: .star, points: 6, innerRatio: 0.5)
    static let a = HaloPoint(x: 760, y: 340), b = HaloPoint(x: 1160, y: 740)

    @Test func aDragIsADraftWithTheToolsOptions() throws {
        let drawn = try #require(HaloShapeDrawn(Self.star, from: Self.b, to: Self.a))
        #expect(drawn.box == Rect(minX: 760, minY: 340, maxX: 1160, maxY: 740) && drawn.spec == Self.star && drawn.name == "Star")
        let outline = try #require(drawn.outline.first)
        #expect(drawn.outline.count == 1 && outline.count >= 12 && outline.allSatisfy { $0.x >= 759.9 && $0.x <= 1160.1 && $0.y >= 339.9 && $0.y <= 740.1 })
    }

    @Test func aClickDrawsNothingShiftSquaresALineKeepsItsEnds() throws {
        #expect(HaloShapeDrawn(Self.star, from: Self.a, to: Self.a) == nil)
        let square = try #require(HaloShapeDrawn(.defaults(.rectangle), from: Self.a, to: HaloPoint(x: 860, y: 380), modifiers: .shift))
        #expect(square.box.width == 100 && square.box.height == 100)
        let line = try #require(HaloShapeDrawn(.defaults(.line), from: Self.b, to: Self.a))
        #expect(line.spec.start == HaloPoint(x: 1, y: 1) && line.spec.end == HaloPoint(x: 0, y: 0))
    }

    @Test func oneReleaseIsOneShape() throws {
        var gesture = HaloShapeGesture()
        for i in 1...120 { gesture.drag(Self.star, from: Self.a, to: HaloPoint(x: 760 + Double(i) * 10 / 3, y: 340 + Double(i) * 10 / 3)) }
        #expect(gesture.isDragging && gesture.draft?.box == Rect(minX: 760, minY: 340, maxX: 1160, maxY: 740))
        let first = gesture.release(), second = gesture.release()
        #expect(first?.box.width == 400)
        #expect(second == nil, "a second release draws again")
        #expect(gesture.draft == nil && !gesture.isDragging)
    }

    @Test func escapeDropsTheDragAndItsRelease() {
        var gesture = HaloShapeGesture()
        gesture.drag(Self.star, from: Self.a, to: Self.b)
        let dropped = gesture.escape()
        #expect(dropped && gesture.draft == nil)
        gesture.drag(Self.star, from: Self.a, to: Self.b)  // the same press keeps moving
        #expect(gesture.draft == nil)
        let cancelled = gesture.release()
        #expect(cancelled == nil)
        gesture.drag(Self.star, from: Self.a, to: Self.b)
        let next = gesture.release(), idle = gesture.escape()
        #expect(next != nil && idle == false)
    }

    @Test func drawingRefusesThroughTheModelWhileTheToolIsAStub() throws {
        var project = HaloProject(services: .fake)
        project.restore(try #require(HaloFixtures.project("three-layers")))
        let before = project.document
        let drawn = try #require(HaloShapeDrawn(Self.star, from: Self.a, to: Self.b))
        let id = project.drawShape(drawn)
        #expect(id == nil)
        #expect(project.document == before && project.history.undo.isEmpty)
        #expect(project.refusal == HaloRefusal(control: "halo.viewer.shape", message: project.shapeHelp ?? ""))
    }
}
