// FlareStageSnapshots.swift: Flare's stage (FlareStage) at 2x through SnapshotHost, in Light, as goldens under
// Golden/flare/: `bounce` at frames 0 and 30, `character` at 12 (its curves must stay curves), a rectangle draft, a
// marquee beside Ball's selection outline, and the Rectangle tool over the locked Background layer, its palette
// button disabled with "Unlock Background to draw on it.". Each also states what the Model hands the stage, so a
// blank stage fails here and not only in the picture. Writes flare-stage-bounce-0@2x, flare-stage-bounce-30@2x,
// flare-stage-character@2x, flare-stage-draft, flare-stage-marquee and flare-stage-locked (each -light.png).
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareStageSnapshots {
    private static let size = CGSize(width: 720, height: 540)

    @Test func bounce() {
        for frame in [0, 30] {
            var model = Self.open("bounce")
            model.setCurrentFrame(frame)
            #expect(model.currentFrame == frame)
            #expect(model.stageList?.items.count == 3, "bounce draws Background, Shadow and Ball")
            check(model, name: "flare-stage-bounce-\(frame)@2x")
        }
    }

    @Test func character() {
        var model = Self.open("character")
        model.setCurrentFrame(12)
        #expect(model.stageList?.items.isEmpty == false)
        check(model, name: "flare-stage-character@2x")
    }

    @Test func draft() {
        var model = Self.open("bounce")
        model.selectTool(.rectangle)
        model.selectLayer("ball")
        model.dragChanged(from: Point(x: 300, y: 60), to: Point(x: 460, y: 180))
        #expect(model.stageMarks.draft != nil, "a rectangle drag shows its draft before mouse-up")
        check(model, name: "flare-stage-draft")
    }

    /// Two pen clicks leave an open path, so Finish Path in the palette is on, with no reason.
    @Test func penDraft() {
        var model = Self.open("bounce")
        model.selectTool(.pen)
        model.drag(from: Point(x: 300, y: 60), to: Point(x: 300, y: 60))
        model.drag(from: Point(x: 460, y: 180), to: Point(x: 460, y: 180))
        #expect(model.finishPathHelp == nil, "two pen clicks should leave a path Finish Path can commit")
        check(model, name: "flare-stage-pen-draft")
    }

    @Test func marquee() {
        var model = Self.open("bounce")
        model.selectTool(.select)
        model.drag(from: Point(x: 80, y: 100), to: Point(x: 80, y: 100))
        model.dragChanged(from: Point(x: 300, y: 40), to: Point(x: 500, y: 200))
        #expect(model.stageMarks.marquee != nil && model.stageMarks.selection != nil)
        check(model, name: "flare-stage-marquee")
    }

    @Test func locked() {
        var model = Self.open("bounce")
        model.selectTool(.rectangle)
        model.selectLayer("background")
        #expect(model.toolHelp(.rectangle) == "Unlock Background to draw on it.")
        check(model, name: "flare-stage-locked")
    }

    /// The fixture `name` on the built services, as the app opens it.
    private static func open(_ name: String) -> FlareWorkspace {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", name]))
        #expect(model.selectedScene != nil, "\(name) opened no scene")
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
