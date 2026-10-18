// KeyRulesTests.swift (editor-kernel EK-14, slice EK-keys): checks first for
// `KeyRules`, the one set of key rules every timeline shares: the key state,
// toggling a key and animation, moving keys (clamped, all or nothing),
// removing keys under both policies, and inserting and removing frames; KJ4,
// the keys walk, closes the file. Disabled until EK-16 writes the bodies.
import Testing
import SuiteKernel

@Suite(.disabled("waits on EK-16")) struct KeyRulesTests {
    /// Four keys like the packet's `bounceTrack`: 0, 10, 20 and 30.
    let bounce = [Keyframe(frame: 0, value: 0), Keyframe(frame: 10, value: 100, easing: .easeOut),
                  Keyframe(frame: 20, value: 0, easing: .easeIn), Keyframe(frame: 30, value: 50)]

    private func frames(_ track: [Keyframe]) -> [Int] { track.map(\.frame) }

    // MARK: state

    @Test func emptyIsNotAnimated() {
        #expect(KeyRules.state([], at: 0) == .notAnimated)
    }

    @Test func oneKeyIsNotAnimated() {
        let one = [Keyframe(frame: 5, value: 1)]
        #expect(KeyRules.state(one, at: 5) == .notAnimated)
        #expect(KeyRules.state(one, at: 0) == .notAnimated)
    }

    @Test func keyedHereOnAKey() {
        #expect(KeyRules.state(bounce, at: 10) == .keyedHere)
        #expect(KeyRules.state(bounce, at: 0) == .keyedHere)
    }

    @Test func animatedBetweenKeys() {
        #expect(KeyRules.state(bounce, at: 15) == .animated)
        #expect(KeyRules.state(bounce, at: 40) == .animated)
    }

    // MARK: toggleKey

    @Test func toggleAddsAKeyInOrder() {
        var track = bounce
        #expect(KeyRules.toggleKey(&track, at: 15, value: 7, leaving: .singleStays))
        #expect(frames(track) == [0, 10, 15, 20, 30])
        #expect(track.first { $0.frame == 15 }?.value == 7)
    }

    @Test func toggleRemovesTheKeyThere() {
        var track = bounce
        #expect(KeyRules.toggleKey(&track, at: 20, value: 7, leaving: .singleStays))
        #expect(frames(track) == [0, 10, 30])
    }

    @Test func toggleLeavingOneKeyFollowsThePolicy() {
        var stays = [Keyframe(frame: 0, value: 1), Keyframe(frame: 10, value: 2)]
        #expect(KeyRules.toggleKey(&stays, at: 10, value: 0, leaving: .singleStays))
        #expect(stays == [Keyframe(frame: 0, value: 1)])
        var goes = [Keyframe(frame: 0, value: 1), Keyframe(frame: 10, value: 2)]
        #expect(KeyRules.toggleKey(&goes, at: 10, value: 0, leaving: .propertyGoesStatic))
        #expect(goes.isEmpty)
    }

    // MARK: toggleAnimated

    @Test func toggleAnimatedKeysAStaticProperty() {
        var track: [Keyframe] = []
        #expect(KeyRules.toggleAnimated(&track, at: 0, lastFrame: 30, value: 4))
        #expect(frames(track) == [0, 30])
        #expect(track.allSatisfy { $0.value == 4 })
        #expect(KeyRules.state(track, at: 30) == .keyedHere)
    }

    @Test func toggleAnimatedMakesAnAnimatedPropertyStatic() {
        var track = bounce
        #expect(KeyRules.toggleAnimated(&track, at: 15, lastFrame: 30, value: 4))
        #expect(track.isEmpty)
        #expect(KeyRules.state(track, at: 15) == .notAnimated)
    }

    // MARK: moveKeys

    @Test func moveShiftsTheChosenKeysOnEveryTrack() throws {
        var tracks = ["x": bounce, "y": [Keyframe(frame: 10, value: 1), Keyframe(frame: 30, value: 2)]]
        try KeyRules.moveKeys(&tracks, [10], by: 3, clampedTo: 0...40)
        #expect(tracks["x"].map(frames) == [0, 13, 20, 30])
        #expect(tracks["y"].map(frames) == [13, 30])
        #expect(tracks["x"]?.first { $0.frame == 13 }?.easing == .easeOut)
    }

    @Test func moveRefusesPastEnd() {
        var tracks = ["x": bounce]
        let error = #expect(throws: KeyRefusal.self) { try KeyRules.moveKeys(&tracks, [20, 30], by: 15, clampedTo: 0...40) }
        #expect({ if case .pastRange? = error { true } else { false } }())
        #expect(tracks["x"] == bounce)
    }

    @Test func moveRefusesPastStart() {
        var tracks = ["x": bounce]
        let error = #expect(throws: KeyRefusal.self) { try KeyRules.moveKeys(&tracks, [0, 10], by: -1, clampedTo: 0...40) }
        #expect({ if case .pastRange? = error { true } else { false } }())
        #expect(tracks["x"] == bounce)
    }

    @Test func moveRefusesLandingOnAKeyThatStays() {
        var tracks = ["x": bounce]
        let error = #expect(throws: KeyRefusal.self) { try KeyRules.moveKeys(&tracks, [10], by: 10, clampedTo: 0...40) }
        #expect({ if case .collides? = error { true } else { false } }())
        #expect(tracks["x"] == bounce)
    }

    @Test func moveOntoAKeyThatAlsoMovesIsFine() throws {
        var tracks = ["x": bounce]
        try KeyRules.moveKeys(&tracks, [10, 20], by: 10, clampedTo: 0...40)
        #expect(tracks["x"].map(frames) == [0, 20, 30, 40])
        #expect(tracks["x"]?.first { $0.frame == 20 }?.value == 100)
    }

    // MARK: removeKeys

    @Test func removeDropsTheChosenKeys() {
        var track = bounce
        KeyRules.removeKeys(&track, [10, 30], leaving: .singleStays)
        #expect(frames(track) == [0, 20])
    }

    @Test func singleStaysKeepsTheLastKey() {
        var track = bounce
        KeyRules.removeKeys(&track, [0, 10, 30], leaving: .singleStays)
        #expect(frames(track) == [20])
    }

    @Test func staticWhenOneLeft() {
        var track = bounce
        KeyRules.removeKeys(&track, [0, 10, 30], leaving: .propertyGoesStatic)
        #expect(track.isEmpty)
    }

    @Test func staticPolicyKeepsTwoOrMore() {
        var track = bounce
        KeyRules.removeKeys(&track, [0, 10], leaving: .propertyGoesStatic)
        #expect(frames(track) == [20, 30])
    }

    // MARK: insertFrames and removeFrames

    @Test func insertMovesLaterKeysLater() {
        var track = bounce
        KeyRules.insertFrames(&track, 5, at: 15)
        #expect(frames(track) == [0, 10, 25, 35])
    }

    @Test func insertKeepsKeyAtFrame() {
        var track = bounce
        KeyRules.insertFrames(&track, 5, at: 10)
        #expect(frames(track) == [0, 10, 25, 35])
    }

    @Test func removeFramesDropsKeysInsideAndPullsLaterKeys() {
        var track = bounce
        KeyRules.removeFrames(&track, 10, at: 10)
        #expect(frames(track) == [0, 10, 20])
        #expect(track.map(\.value) == [0, 0, 50])
    }

    @Test func removeFramesBeforeEveryKeyOnlyShifts() {
        var track = [Keyframe(frame: 10, value: 1), Keyframe(frame: 20, value: 2)]
        KeyRules.removeFrames(&track, 4, at: 2)
        #expect(frames(track) == [6, 16])
    }

    // MARK: KJ4

    /// KJ4, the keys walk: animate a static property, key the middle, read the
    /// state, move a key, insert frames, then remove keys back to static.
    @Test func keysWalk() throws {
        var track: [Keyframe] = []
        #expect(KeyRules.state(track, at: 0) == .notAnimated)
        #expect(KeyRules.toggleAnimated(&track, at: 0, lastFrame: 20, value: 1))
        #expect(KeyRules.toggleKey(&track, at: 10, value: 5, leaving: .propertyGoesStatic))
        #expect(KeyRules.state(track, at: 10) == .keyedHere && KeyRules.state(track, at: 5) == .animated)
        var tracks = ["opacity": track]
        try KeyRules.moveKeys(&tracks, [10], by: 2, clampedTo: 0...20)
        track = tracks["opacity"] ?? []
        #expect(frames(track) == [0, 12, 20])
        KeyRules.insertFrames(&track, 3, at: 12)
        #expect(frames(track) == [0, 12, 23])
        KeyRules.removeKeys(&track, [0, 12], leaving: .propertyGoesStatic)
        #expect(track.isEmpty && KeyRules.state(track, at: 12) == .notAnimated)
    }
}
