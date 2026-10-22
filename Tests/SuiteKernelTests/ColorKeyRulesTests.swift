// ColorKeyRulesTests.swift (timeline-keys TK-1 checks, TK-5 turns them on):
// `ColorKeyRules`, the colour-track twin of `KeyRules`: the same frame rules
// for a key button's state, a toggle that removes the key at a keyed frame by
// its `RemovePolicy`, and sampling through FlareCore's colour easing. MJ-TK.
import Testing
import SuiteKernel

@Suite struct ColorKeyRulesTests {
    /// Blue at 0, orange at 30, linear: the packet's fill-colour walk.
    let blueToOrange = [ColorKeyframe(frame: 0, value: .init(r: 0, g: 0, b: 1)),
                        ColorKeyframe(frame: 30, value: .init(r: 1, g: 0.5, b: 0))]

    private func frames(_ track: [ColorKeyframe]) -> [Int] { track.map(\.frame) }

    @Test(.disabled("waits on TK-5")) func stateFollowsTheFrameRules() {
        #expect(ColorKeyRules.state([], at: 0) == .notAnimated)
        #expect(ColorKeyRules.state([ColorKeyframe(frame: 5, value: .init(r: 1, g: 1, b: 1))], at: 5) == .notAnimated)
        #expect(ColorKeyRules.state(blueToOrange, at: 0) == .keyedHere)
        #expect(ColorKeyRules.state(blueToOrange, at: 30) == .keyedHere)
        #expect(ColorKeyRules.state(blueToOrange, at: 15) == .animated)
    }

    @Test(.disabled("waits on TK-5")) func toggleAddsAKeyInOrder() {
        var track = blueToOrange
        let changed = ColorKeyRules.toggleKey(&track, at: 12, value: .init(r: 0, g: 1, b: 0), leaving: .singleStays)
        #expect(changed)
        #expect(frames(track) == [0, 12, 30])
        #expect(track.count == 3 && track[1].value.g == 1)
    }

    @Test(.disabled("waits on TK-5")) func toggleRemovesKey() {
        var track = blueToOrange + [ColorKeyframe(frame: 45, value: .init(r: 0, g: 1, b: 0))]
        #expect(ColorKeyRules.toggleKey(&track, at: 30, value: .init(r: 0, g: 0, b: 0), leaving: .singleStays))
        #expect(frames(track) == [0, 45])
    }

    @Test(.disabled("waits on TK-5")) func lastKeysGoStaticByPolicy() {
        var goesStatic = blueToOrange
        _ = ColorKeyRules.toggleKey(&goesStatic, at: 30, value: .init(r: 0, g: 0, b: 0), leaving: .propertyGoesStatic)
        #expect(goesStatic.isEmpty)
        var stays = blueToOrange
        _ = ColorKeyRules.toggleKey(&stays, at: 30, value: .init(r: 0, g: 0, b: 0), leaving: .singleStays)
        #expect(frames(stays) == [0])
        #expect(stays.first?.value.b == 1)
    }

    @Test(.disabled("waits on TK-5")) func samplesTheMidColour() throws {
        let mid = try #require(ColorKeyRules.sample(blueToOrange, at: 15))
        #expect(abs(mid.r - 0.5) < 1e-9 && abs(mid.g - 0.25) < 1e-9 && abs(mid.b - 0.5) < 1e-9 && mid.a == 1)
        let quarter = try #require(ColorKeyRules.sample(blueToOrange, at: 6))
        #expect(abs(quarter.r - 0.2) < 1e-9)
    }

    @Test(.disabled("waits on TK-5")) func samplesHoldTheEnds() throws {
        #expect(try #require(ColorKeyRules.sample(blueToOrange, at: 0)).b == 1)
        #expect(try #require(ColorKeyRules.sample(blueToOrange, at: 60)).r == 1)
        #expect(ColorKeyRules.sample([], at: 0) == nil)
    }

    @Test(.disabled("waits on TK-5")) func samplesWithTheKeysEasing() throws {
        var held = blueToOrange
        held[0].easing = .hold
        #expect(try #require(ColorKeyRules.sample(held, at: 29)).b == 1)
    }
}
