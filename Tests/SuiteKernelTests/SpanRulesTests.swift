// SpanRulesTests.swift (timeline-keys TK-1 checks, TK-5 turns them on):
// `SpanRules.slide`, a layer's span and every key on its tracks moving by
// one delta, clamped so the span stays inside 0...lastFrame; the keys move
// through `KeyRules.moveKeys`, all or nothing. MJ-TK.
import Testing
import SuiteKernel

@Suite struct SpanRulesTests {
    /// x keyed at 10 and 20, opacity at 10 and 16: a layer spanning 10...40.
    let tracks: [String: [Keyframe]] = [
        "x": [Keyframe(frame: 10, value: 0), Keyframe(frame: 20, value: 100)],
        "opacity": [Keyframe(frame: 10, value: 0), Keyframe(frame: 16, value: 1)],
    ]

    private func frames(_ tracks: [String: [Keyframe]]) -> [String: [Int]] { tracks.mapValues { $0.map(\.frame) } }

    @Test(.disabled("waits on TK-5")) func slideMovesSpanAndKeys() throws {
        var span = 10...40, keys = tracks
        let delta = try SpanRules.slide(&span, tracks: &keys, by: 6, lastFrame: 47)
        #expect(delta == 6)
        #expect(span == 16...46)
        #expect(frames(keys) == ["x": [16, 26], "opacity": [16, 22]])
    }

    @Test(.disabled("waits on TK-5")) func keysFollowClamp() throws {
        var span = 10...40, keys = tracks
        let delta = try SpanRules.slide(&span, tracks: &keys, by: 20, lastFrame: 47)
        #expect(delta == 7)
        #expect(span == 17...47)
        #expect(frames(keys) == ["x": [17, 27], "opacity": [17, 23]])
    }

    @Test(.disabled("waits on TK-5")) func staysInComp() throws {
        var span = 10...40, keys = tracks
        let delta = try SpanRules.slide(&span, tracks: &keys, by: -25, lastFrame: 47)
        #expect(delta == -10)
        #expect(span == 0...30)
        #expect(frames(keys) == ["x": [0, 10], "opacity": [0, 6]])
    }

    @Test(.disabled("waits on TK-5")) func zeroMovesNothing() throws {
        var span = 0...47, keys = tracks
        #expect(try SpanRules.slide(&span, tracks: &keys, by: 6, lastFrame: 47) == 0)
        #expect(span == 0...47)
        #expect(keys == tracks)
    }

    @Test(.disabled("waits on TK-5")) func keyPastTheCompRefusesWhole() {
        var span = 10...20, keys = tracks
        keys["x", default: []].append(Keyframe(frame: 45, value: 50))
        let before = keys
        #expect(throws: KeyRefusal.pastRange(frame: 55)) {
            try SpanRules.slide(&span, tracks: &keys, by: 10, lastFrame: 47)
        }
        #expect(span == 10...20)
        #expect(keys == before)
    }

    @Test(.disabled("waits on TK-5")) func spanLongerThanTheCompStaysAtZero() throws {
        var span = 0...50, keys: [String: [Keyframe]] = [:]
        #expect(try SpanRules.slide(&span, tracks: &keys, by: -6, lastFrame: 47) == 0)
        #expect(span == 0...50)
    }
}
