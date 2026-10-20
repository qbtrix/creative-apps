// FlareViewSnapshots.swift: stage-edit SE-2 on `bounce`: at 200% with guides at x 150 and y 60 dragged to y 110
// (drawn where the drag is), and at the fit with the rulers hidden. Goldens flare-view-*-light.png.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareViewSnapshots {
    private static let size = CGSize(width: 720, height: 540)

    @Test func guides() {
        var model = Self.bounce()
        model.addGuide(.horizontal, at: 60)
        model.addGuide(.vertical, at: 150)
        var drag = FlareGuideDrag(guide: 0, of: model.guides)
        drag?.move(to: 110)
        let stage = FlareStage(
            model: model, zoom: 2, showsRulers: true, showsGuides: true, perform: { _ in }, help: { _ in nil },
            guideDrag: drag)
        assertGolden(stage, size: Self.size, name: "flare-view-guides@2x", area: "flare", appearance: .light)
    }

    @Test func noRulers() {
        var model = Self.bounce()
        model.addGuide(.horizontal, at: 300)
        let scene = CGSize(width: 550, height: 400)
        let viewport = CGSize(width: Self.size.width - SuiteSize.ruler, height: Self.size.height - SuiteSize.ruler)
        let stage = FlareStage(
            model: model, zoom: ZoomMath.fit(document: scene, in: viewport), showsRulers: false, showsGuides: true,
            perform: { _ in }, help: { _ in nil })
        assertGolden(stage, size: Self.size, name: "flare-view-norulers", area: "flare", appearance: .light)
    }

    private static func bounce() -> FlareWorkspace {
        FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
    }
}
