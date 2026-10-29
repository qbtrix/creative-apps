// DesignKeyToggleTests.swift: the inspector's key button on a layer's X, Y and Opacity rows (one-document OD-13), on
// the Model side. Its presence is KeyRules.state of the row's track at the playhead (frame 0 with none); a press runs
// OD-8's keyframe.set with the layer's own value there, or keyframe.remove when a key sits at that frame. The first
// press on a still file makes it animated, so the timeline slides in. Linux-safe.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignKeyToggleTests {
    static func press(_ w: inout DesignWorkspace, _ property: DesignKeyProperty = .x) throws -> String? {
        guard let command = w.keyToggle("node-2", property) else { return nil }
        return try DesignWorkspace.catalog.run(command.id, params: command.params, on: &w).undoStep
    }
    static func track(_ w: DesignWorkspace, _ property: DesignKeyProperty = .x) -> [Keyframe] {
        w.findNode("node-2")?.time?.tracks[property] ?? []
    }

    @Test func theFirstPressKeysTheRestValueAtFrameZeroAndShowsTheTimeline() throws {
        var w = DesignFixtures.cards
        #expect(w.keyState("node-2", .x) == .notAnimated && !w.showsTimeline)
        #expect(try Self.press(&w) == "Set Key")
        #expect(Self.track(w).map(\.frame) == [0] && Self.track(w).map(\.value) == [100])
        #expect(w.keyState("node-2", .x) == .keyedHere && w.showsTimeline)
    }

    @Test func atThePlayheadAPressAddsThenRemovesTheKeyThere() throws {
        var w = DesignFixtures.cards
        _ = try Self.press(&w)
        w.setPlayhead(60)
        #expect(w.keyState("node-2", .x) == .animated)
        #expect(try Self.press(&w) == "Set Key")
        #expect(Self.track(w).map(\.frame) == [0, 60] && Self.track(w).map(\.value) == [100, 100], "the value it shows there")
        #expect(w.keyState("node-2", .x) == .keyedHere)
        #expect(try Self.press(&w) == "Remove Key")
        #expect(Self.track(w).map(\.frame) == [0])
    }

    @Test func eachRowKeysItsOwnTrack() throws {
        var w = DesignFixtures.cards
        w.setPlayhead(30)
        _ = try Self.press(&w, .opacity)
        #expect(Self.track(w, .opacity).map(\.frame) == [30] && Self.track(w, .opacity).map(\.value) == [1])
        #expect(Self.track(w).isEmpty && w.keyState("node-2", .y) == .notAnimated)
    }

    @Test func anUnknownLayerHasNoButton() {
        let w = DesignFixtures.cards
        #expect(w.keyState("nope", .x) == nil && w.keyToggle("nope", .x) == nil)
    }
}
