// FlareShapeDraftTests.swift: shape-tools FS-3 (docs/blueprints/flare/features/shape-tools.md). During a Shape drag
// the stage's overlay strokes the draft's own path: a star previews as the kernel's star at the stage zoom, not its
// box, and every kind previews as the kernel draws it. macOS only.
#if canImport(CoreGraphics)
import CoreGraphics
import FlareCore
import FlareModel
import SuiteKernel
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareShapeDraftTests {
    private static let a = Point(x: 300, y: 60), b = Point(x: 460, y: 180), zoom = 1.5

    /// The kernel's drawing of `spec` for the drag, as the overlay would stroke it at `zoom`.
    private static func kernel(_ spec: ShapeSpec) throws -> CGPath {
        let (box, dragged) = try #require(ShapeRules.dragged(spec.kind, from: a, to: b, modifiers: []))
        var drawn = spec
        (drawn.start, drawn.end) = (dragged.start, dragged.end)
        return StagePath.cgPath(try ShapeRules.path(drawn, in: box), transform: .scale(x: zoom, y: zoom))
    }

    private static func shapeDrag(_ spec: ShapeSpec) -> FlareWorkspace {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.selectTool(.shape)
        model.pickShapeTool(spec)
        model.dragChanged(from: a, to: b)
        return model
    }

    @Test func aStarDraftPreviewsOnTheStageDuringTheDrag() throws {
        let model = Self.shapeDrag(.defaults(.star))
        let drawn = try #require(FlareStageOverlay.draftPath(model.stageMarks, zoom: Self.zoom),
                                 "a Shape drag shows its draft before mouse-up")
        #expect(drawn == (try Self.kernel(.defaults(.star))))
        #expect(!drawn.isRect(nil), "the star draft is not its box")
    }

    @Test func everyKindPreviewsItsOwnPath() throws {
        for kind in ShapeKind.allCases {
            let model = Self.shapeDrag(.defaults(kind))
            let drawn = try #require(FlareStageOverlay.draftPath(model.stageMarks, zoom: Self.zoom), "\(kind)")
            #expect(drawn == (try Self.kernel(.defaults(kind))), "\(kind)")
        }
    }

    @Test func noDraftDrawsNothing() {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        #expect(FlareStageOverlay.draftPath(model.stageMarks, zoom: Self.zoom) == nil)
    }
}
#endif
