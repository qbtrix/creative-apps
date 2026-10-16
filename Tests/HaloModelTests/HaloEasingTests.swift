// HaloEasingTests.swift: EZ-3 (#428). Easing the picked keys on `keyed`
// (Ball: x 160 at 0 and 960 at 24, opacity 0 at 0 and 1 at 12) over `.fake`
// and `.live`: HF-4's exact samples for each preset, one "Keyframe Easing"
// step per chip or whole handle drag, the handles and curve the inspector
// draws, the file round trip, and H-J7 steps 1 to 8 on the Model. Linux and
// macOS.
@testable import HaloModel
import Testing

private let easingServices: [HaloServices] = [.fake, .live]

/// `keyed` on `services` with Ball selected; Ball's id.
private func ballProject(_ services: HaloServices) throws -> (project: HaloProject, ball: String) {
    var project = commandProject("keyed", services)
    let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" }).id
    project.selectLayer(ball)
    return (project, ball)
}

/// `keyed` with Ball selected and its Position X 0 key picked.
private func pickedX0(_ services: HaloServices) throws -> (project: HaloProject, ball: String) {
    var (project, ball) = try ballProject(services)
    project.selectKey(HaloKeyRef(layerID: ball, property: .x, frame: 0), extending: false)
    return (project, ball)
}

/// Ball's Position X row at `frame`, as the inspector shows it.
private func positionX(_ project: inout HaloProject, at frame: Int) throws -> HaloPropertyRow {
    project.scrub(to: frame)
    return try #require(project.propertyRows.first { $0.property == .x })
}

private func xEasing(_ project: HaloProject) -> String? {
    project.keySegments.first { $0.key.property == .x }?.easingTitle
}

@Test(arguments: easingServices)
func positionFollowsEachPreset(_ services: HaloServices) throws {
    for preset in HaloEasingPreset.allCases {
        var project = try pickedX0(services).project
        project.setEasing(preset)
        for frame in [6, 12, 18] {
            let expected = 160 + 800 * preset.easing.value(at: Double(frame) / 24)
            #expect(try positionX(&project, at: frame).value == expected, "\(preset) at \(frame)")
        }
        if preset == .hold {
            for frame in [6, 12, 18, 23] { #expect(try positionX(&project, at: frame).value == 160) }
        }
    }
}

@Test(arguments: easingServices)
func eachPresetBendsTheMidpointTheRightWay(_ services: HaloServices) throws {
    var (project, _) = try pickedX0(services)
    project.setEasing(.easeIn)
    #expect(try positionX(&project, at: 12).value < 560)
    project.setEasing(.easeOut)
    #expect(try positionX(&project, at: 12).value > 560)
    project.setEasing(.linear)
    #expect(try positionX(&project, at: 12).value == 560)
    project.setEasing(.hold)
    #expect(try positionX(&project, at: 23).value == 160)
    #expect(try positionX(&project, at: 24).value == 960)
}

@Test(arguments: easingServices)
func twoPickedKeysAreOneStepAndOneUndo(_ services: HaloServices) throws {
    var (project, ball) = try ballProject(services)
    project.selectLaneKeys(layerID: ball, frame: 0, extending: false)
    #expect(project.pickedKeys.count == 2)
    project.setEasing(.easeIn)
    #expect(project.history.undo.count == 1)
    #expect(project.title(for: .undo) == "Undo Keyframe Easing")
    #expect(project.keySegments.allSatisfy { $0.preset == .easeIn })
    #expect(project.file.unsaved)
    project.setEasing(.easeIn)
    #expect(project.history.undo.count == 1)
    project.undo()
    #expect(project.keySegments.allSatisfy { $0.preset == .linear })
    #expect(project.pickedKeys.count == 2)
}

@Test(arguments: easingServices)
func aHandleDragIsOneStepUntilItEnds(_ services: HaloServices) throws {
    var (project, _) = try pickedX0(services)
    #expect(project.easingHandles?.first == HaloPoint(x: 0, y: 0))
    #expect(project.easingHandles?.second == HaloPoint(x: 1, y: 1))
    for i in 1...30 { project.moveEasingHandle(.first, to: HaloPoint(x: Double(i) / 40, y: 0.1)) }
    #expect(project.history.undo.count == 1)
    #expect(project.title(for: .undo) == "Undo Keyframe Easing")
    #expect(project.easingHandles?.first == HaloPoint(x: 0.75, y: 0.1))
    #expect(project.easingHandles?.second == HaloPoint(x: 1, y: 1))
    #expect(project.pickedPreset == nil)
    #expect(xEasing(project) == "Custom")
    project.endCoalescing()
    project.moveEasingHandle(.second, to: HaloPoint(x: 1.4, y: 1.3))
    #expect(project.history.undo.count == 2)
    #expect(project.easingHandles?.second == HaloPoint(x: 1, y: 1.3))
    let before = project
    project.moveEasingHandle(.first, to: HaloPoint(x: .nan, y: 0))
    project.moveEasingHandle(.first, to: HaloPoint(x: 0.2, y: .infinity))
    #expect(project == before)
}

@Test(arguments: easingServices)
func theCurveFollowsThePickedSegment(_ services: HaloServices) throws {
    var (project, ball) = try ballProject(services)
    #expect(project.easingCurve(count: 5).isEmpty)
    #expect(project.easingHandles == nil)
    project.selectKey(HaloKeyRef(layerID: ball, property: .x, frame: 0), extending: false)
    project.setEasing(.easeIn)
    let curve = project.easingCurve(count: 5)
    #expect(curve.map(\.x) == [0, 0.25, 0.5, 0.75, 1])
    #expect(curve.map(\.y) == curve.map { HaloEasing.easeIn.value(at: $0.x) })
    #expect(project.easingCurve(count: 0).isEmpty)
    #expect(project.easingCurve(count: 1) == [HaloPoint(x: 0, y: 0)])
    #expect(project.easingHandles?.first == HaloPoint(x: 0.42, y: 0))
    project.setEasing(.hold)
    #expect(project.easingHandles?.second == HaloPoint(x: 1, y: 1))
}

@Test(arguments: easingServices)
func nothingPickedIsRefusedAndChangesNothing(_ services: HaloServices) throws {
    var (project, _) = try ballProject(services)
    let document = project.document
    project.setEasing(.easeIn)
    project.moveEasingHandle(.first, to: HaloPoint(x: 0.3, y: 0))
    #expect(project.document == document)
    #expect(project.history.undo.isEmpty)
    #expect(project.refusal?.control == "halo.easing")
}

@Test(arguments: easingServices)
func easingSurvivesSaveAndOpen(_ services: HaloServices) throws {
    var (project, ball) = try pickedX0(services)
    project.setEasing(.easeOut)
    project.selectKey(HaloKeyRef(layerID: ball, property: .opacity, frame: 0), extending: false)
    project.setCustomEasing(.cubicBezier(x1: 0.1, y1: 0.2, x2: 0.3, y2: 1.4), coalesceKey: nil)
    let state = try project.services.files.decode(project.fileData())
    var opened = HaloProject(services: services)
    opened.beginOpen(name: "Bounce.halo", path: "/tmp/Bounce.halo")
    opened.finishOpen(.success(state))
    opened.selectLayer(ball)
    #expect(opened.keySegments.map(\.easing) == [.easeOut, .cubicBezier(x1: 0.1, y1: 0.2, x2: 0.3, y2: 1.4)])
}

/// H-J7 steps 1 to 8 on the Model (EZ-8 walks them on screen).
@Test(arguments: easingServices)
func testEaseKeysJourney(_ services: HaloServices) throws {
    // 1. Select Ball: two segments, none picked.
    var (project, ball) = try ballProject(services)
    #expect(project.keySegments.map(\.title) == ["Position X, frames 0–24", "Opacity, frames 0–12"])
    #expect(project.pickedSegment == nil)
    // 2. Nothing picked (the menu's availability is EZ-5's).
    #expect(project.pickedKeys.isEmpty)
    // 3. Pick the Position X row: Linear, handles at the corners.
    project.selectKey(HaloKeyRef(layerID: ball, property: .x, frame: 0), extending: false)
    #expect(project.pickedPreset == .linear)
    #expect(project.easingHandles?.first == HaloPoint(x: 0, y: 0))
    // 4. Ease In and Out.
    project.setEasing(.easeInOut)
    #expect(xEasing(project) == "Ease In and Out")
    #expect(project.title(for: .undo) == "Undo Keyframe Easing")
    // 5. The symmetric curve keeps the midpoint; frame 6 lags.
    #expect(try positionX(&project, at: 12).text == "560.0 px")
    #expect(try positionX(&project, at: 6).value < 360)
    // 6. Drag the first handle right: custom, still one more step.
    let first = try #require(project.easingHandles?.first)
    project.moveEasingHandle(.first, to: HaloPoint(x: first.x + 0.2, y: first.y))
    project.moveEasingHandle(.first, to: HaloPoint(x: first.x + 0.3, y: first.y))
    project.endCoalescing()
    #expect(project.pickedPreset == nil)
    #expect(xEasing(project) == "Custom")
    #expect(project.title(for: .undo) == "Undo Keyframe Easing")
    #expect(project.history.undo.count == 2)
    // 7. Hold from the timeline's menu.
    project.setEasing(.hold)
    #expect(xEasing(project) == "Hold")
    #expect(try positionX(&project, at: 6).text == "160.0 px")
    // 8. Undo three times; the row stays picked.
    project.undo()
    #expect(xEasing(project) == "Custom")
    project.undo()
    #expect(xEasing(project) == "Ease In and Out")
    project.undo()
    #expect(xEasing(project) == "Linear")
    #expect(try positionX(&project, at: 6).text == "360.0 px")
    #expect(project.pickedKeys == [HaloKeyRef(layerID: ball, property: .x, frame: 0)])
}
