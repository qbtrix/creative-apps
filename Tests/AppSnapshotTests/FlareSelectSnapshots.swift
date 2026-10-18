// FlareSelectSnapshots.swift: stage-edit SE-1, the selection box and its handles on `bounce`: Ball, a marquee over Ball
// and Shadow, a scale before mouse-up, and the locked Background (no box). Goldens flare-select-*-light.png.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareSelectSnapshots {
    private static let size = CGSize(width: 720, height: 540)

    @Test func one() {
        let model = Self.selected([Point(x: 80, y: 100), Point(x: 80, y: 100)])
        #expect(model.selectionReadout.count == 1 && model.selectionReadout.handles.count == 9)
        check(model, name: "flare-select-one@2x")
    }

    @Test func two() {
        let model = Self.selected([Point(x: 40, y: 60), Point(x: 330, y: 370)])
        #expect(model.selectionReadout.count == 2, "the marquee didn't take Ball and Shadow")
        check(model, name: "flare-select-two@2x")
    }

    @Test func scaling() {
        var model = Self.selected([Point(x: 80, y: 100), Point(x: 80, y: 100)])
        if let box = model.selectionBounds {
            let grip = Point(x: box.maxX + 2, y: box.maxY - 2)
            model.dragChanged(from: grip, to: Point(x: grip.x + box.width / 2, y: grip.y + box.height / 2))
        }
        #expect(model.selectionReadout.text == "1 selected, scale 1.50 × 1.50, rotation 0°")
        check(model, name: "flare-select-scaling")
    }

    @Test func locked() {
        var model = Self.selected([])
        model.selectLayer("background")
        #expect(model.selectionReadout.box == nil, "a locked layer picked in the sidebar drew a box")
        check(model, name: "flare-select-locked")
    }

    private static func selected(_ drag: [Point]) -> FlareWorkspace {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.selectTool(.select)
        if drag.count == 2 { model.drag(from: drag[0], to: drag[1]) }
        return model
    }

    private func check(_ model: FlareWorkspace, name: String) {
        let scene = CGSize(width: model.selectedScene?.width ?? 1, height: model.selectedScene?.height ?? 1)
        let viewport = CGSize(width: Self.size.width - SuiteSize.ruler, height: Self.size.height - SuiteSize.ruler)
        let stage = FlareStage(
            model: model, zoom: ZoomMath.fit(document: scene, in: viewport), showsRulers: true, showsGuides: true,
            perform: { _ in }, help: { _ in nil })
        assertGolden(stage, size: Self.size, name: name, area: "flare", appearance: .light)
    }
}
