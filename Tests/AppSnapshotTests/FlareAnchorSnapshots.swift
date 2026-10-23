// FlareAnchorSnapshots.swift (pen-paths FP-3, slice FP-u): the stage's PathEditOverlay (PN-3) on `bounce`, light and
// dark. `directPicked`: Direct Select clicks Ball, so its path shows its anchors and the smooth ones their handles
// (flare-direct-anchors). `anchorSelected`: Ball's first anchor picked, filled in the accent with its handles
// (flare-direct-anchor-selected). `penDrawing`: three Pen presses, the second dragged, leave an open draft with one
// smooth anchor (flare-pen-drawing). Each states what the Model hands the overlay first, so a missing path fails here
// and not only in the picture. Goldens under Golden/flare/, each -light.png and -dark.png.
import FlareCore
import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareAnchorSnapshots {
    private static let size = CGSize(width: 720, height: 540)

    /// Direct Select on Ball: the overlay gets its path, nothing picked yet.
    @Test func directPicked() throws {
        let model = Self.picked()
        let edit = try #require(model.editablePath, "Direct Select on Ball put no path in edit: \(model.pathHelp ?? "")")
        #expect(edit.path.contours.first?.anchors.isEmpty == false && model.anchorSelection.ordered.isEmpty)
        check(model, name: "flare-direct-anchors")
    }

    /// Ball's first anchor picked: the overlay fills it and draws its handles.
    @Test func anchorSelected() throws {
        var model = Self.picked()
        let first = AnchorRef(contour: 0, index: 0)
        model.runPath(.select(anchors: [first], rect: nil, extend: false))
        #expect(model.anchorSelection.ordered == [first])
        #expect(model.editablePath?.path.contours.first?.anchors.first?.handleOut != nil, "Ball's first anchor has no handles")
        check(model, name: "flare-direct-anchor-selected")
    }

    /// Three Pen presses, the second dragged: an open draft of three anchors, the middle one smooth.
    @Test func penDrawing() throws {
        var model = Self.open()
        model.selectTool(.pen)
        model.drag(from: Point(x: 300, y: 60), to: Point(x: 300, y: 60))
        model.drag(from: Point(x: 420, y: 140), to: Point(x: 470, y: 120))
        model.drag(from: Point(x: 360, y: 240), to: Point(x: 360, y: 240))
        let draft = try #require(model.penDraft, "three Pen presses left no draft")
        #expect(draft.contour.anchors.count == 3 && !draft.contour.closed)
        #expect(draft.contour.anchors.dropFirst().first?.handleOut != nil, "the dragged press made no smooth anchor")
        check(model, name: "flare-pen-drawing")
    }

    /// `bounce` on the built services, as the app opens it.
    private static func open() -> FlareWorkspace {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        #expect(model.selectedScene != nil, "bounce opened no scene")
        return model
    }

    /// `bounce` with Ball clicked by Direct Select.
    private static func picked() -> FlareWorkspace {
        var model = open()
        model.selectTool(.directSelect)
        model.drag(from: Point(x: 80, y: 100), to: Point(x: 80, y: 100))
        return model
    }

    private func check(_ model: FlareWorkspace, name: String) {
        let scene = CGSize(width: model.selectedScene?.width ?? 1, height: model.selectedScene?.height ?? 1)
        let viewport = CGSize(width: Self.size.width - SuiteSize.ruler, height: Self.size.height - SuiteSize.ruler)
        let stage = FlareStage(
            model: model, zoom: ZoomMath.fit(document: scene, in: viewport), showsRulers: true, showsGuides: true,
            perform: { _ in }, help: { _ in nil })
        for appearance in [SnapshotAppearance.light, .dark] {
            assertGolden(stage, size: Self.size, name: name, area: "flare", appearance: appearance)
        }
    }
}
