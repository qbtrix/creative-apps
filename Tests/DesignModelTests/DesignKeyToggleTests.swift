// DesignKeyToggleTests.swift: the inspector's key button on a layer's X, Y and Opacity rows and the Animate menu
// (one-document OD-13), on the Model side. The button's state is KeyRules.state of the row's track at the playhead
// (frame 0 with none). Its stopwatch animates the row (keys at the playhead and the last frame) or leaves one held key;
// its diamond sets the key at the playhead with the value shown there, or removes the one there. Each runs OD-8's
// keyframe.set and keyframe.remove. The first key on a still file shows the timeline. Linux-safe.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignKeyToggleTests {
    static func run(_ w: inout DesignWorkspace, _ commands: [(id: String, params: JSONValue)]?) throws -> [String?] {
        try (commands ?? []).map { try DesignWorkspace.catalog.run($0.id, params: $0.params, on: &w).undoStep }
    }
    static func track(_ w: DesignWorkspace, _ property: DesignKeyProperty = .x) -> [Keyframe] {
        w.findNode("node-2")?.time?.tracks[property] ?? []
    }

    @Test func theStopwatchAnimatesTheRowToTheLastFrameAndShowsTheTimeline() throws {
        var w = DesignFixtures.cards
        #expect(w.keyState("node-2", .x) == .notAnimated && !w.showsTimeline)
        #expect(try Self.run(&w, w.keyAnimate("node-2", .x)) == ["Set Key", "Set Key"])
        #expect(Self.track(w).map(\.frame) == [0, w.time.durationFrames - 1] && Self.track(w).map(\.value) == [100, 100])
        #expect(w.keyState("node-2", .x) == .keyedHere && w.showsTimeline)
    }

    @Test func theStopwatchOnAnAnimatedRowLeavesOneHeldKey() throws {
        var w = DesignFixtures.cards
        _ = try Self.run(&w, w.keyAnimate("node-2", .x))
        #expect(try Self.run(&w, w.keyAnimate("node-2", .x)) == ["Remove Key"])
        #expect(Self.track(w).map(\.frame) == [0] && w.keyState("node-2", .x) == .notAnimated)
    }

    @Test func atThePlayheadTheDiamondAddsThenRemovesTheKeyThere() throws {
        var w = DesignFixtures.cards
        _ = try Self.run(&w, w.keyAnimate("node-2", .x))
        let params: JSONValue = .object(["node": .string("node-2"), "property": .string("x"), "frame": .number(0), "value": .number(40)])
        _ = try DesignWorkspace.catalog.run("keyframe.set", params: params, on: &w)
        w.setPlayhead(60)
        let shown = try #require(w.sampledNode("node-2", at: 60)?.frame.x)
        #expect(w.keyState("node-2", .x) == .animated && shown != 40 && shown != 100)
        #expect(try Self.run(&w, w.keyToggle("node-2", .x).map { [$0] }) == ["Set Key"])
        #expect(Self.track(w).map(\.frame) == [0, 60, w.time.durationFrames - 1])
        #expect(Self.track(w)[1].value == shown, "the value its track shows there, not the rest value")
        #expect(w.keyState("node-2", .x) == .keyedHere)
        #expect(try Self.run(&w, w.keyToggle("node-2", .x).map { [$0] }) == ["Remove Key"])
        #expect(Self.track(w).map(\.frame) == [0, w.time.durationFrames - 1])
    }

    @Test func eachRowKeysItsOwnTrack() throws {
        var w = DesignFixtures.cards
        w.setPlayhead(30)
        _ = try Self.run(&w, w.keyAnimate("node-2", .opacity))
        #expect(Self.track(w, .opacity).map(\.frame) == [30, w.time.durationFrames - 1] && Self.track(w, .opacity).map(\.value) == [1, 1])
        #expect(Self.track(w).isEmpty && w.keyState("node-2", .y) == .notAnimated)
    }

    @Test func anUnknownLayerHasNoButton() {
        let w = DesignFixtures.cards
        #expect(w.keyState("nope", .x) == nil && w.keyToggle("nope", .x) == nil && w.keyAnimate("nope", .x) == nil)
    }

    @Test func theMenuKeysEveryRowOfTheSelectedLayerOnce() throws {
        var w = DesignFixtures.cards
        #expect(w.menuKeys(removing: false).isEmpty, "no layer selected")
        w.selectItem("node-2")
        #expect(w.menuKeys(removing: true).isEmpty)
        #expect(try Self.run(&w, w.menuKeys(removing: false)) == ["Set Key", "Set Key", "Set Key"])
        #expect(DesignKeyProperty.allCases.allSatisfy { Self.track(w, $0).map(\.frame) == [0] })
        #expect(w.menuKeys(removing: false).isEmpty, "every row is keyed at this frame")
    }

    /// The menu item's reason, read as the menu reads it: through its spec over the menu state.
    static func why(_ state: DesignMenuState, _ id: String) -> String? { DesignMenuState.spec(id).availability(state).why }

    @Test func theAnimateMenuSaysWhyItIsOff() throws {
        var w = DesignFixtures.cards
        let still = DesignMenuState(workspace: w, hasWindow: true)
        #expect(Self.why(still, "animate.play-pause") == "Set a key first.")
        #expect(Self.why(still, "animate.stop") == "Set a key first.")
        #expect(Self.why(still, "keyframe.remove") == "Set a key first.")
        #expect(Self.why(still, "keyframe.set") == DesignRefusal.nothingSelected.help)
        w.selectItem("node-2")
        _ = try Self.run(&w, w.keyAnimate("node-2", .x))
        let keyed = DesignMenuState(workspace: w, hasWindow: true)
        #expect(Self.why(keyed, "animate.play-pause") == nil && Self.why(keyed, "keyframe.remove") == nil)
        #expect(Self.why(keyed, "keyframe.set") == nil, "y and opacity have no key at frame 0")
    }
}
