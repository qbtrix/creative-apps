// DesignNodeTimeTests.swift: the conformance suite for the frozen node-time contract (DesignNodeTime.swift). Sampling
// at, before, between and past keys; eased and held segments; a subtree moving by its keyed parent's delta; a still
// node sampling to itself; the file shape (round trip, no `time` key on a still node, an unknown property refused);
// the animated fixtures; and a still document saving byte for byte as before time existed. Linux-safe.
import Foundation
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignNodeTimeTests {
    static func rect(_ id: String, _ x: Double, _ y: Double, time: DesignNodeTime? = nil) -> DesignNode {
        var node = DesignNode(id: id, name: id, kind: .rectangle, frame: DesignRect(x: x, y: y, width: 20, height: 10))
        node.time = time
        return node
    }

    /// x keyed 10 at frame 0 to 130 at frame 120, linear.
    static let slide = DesignNodeTime(tracks: [.x: [Keyframe(frame: 0, value: 10), Keyframe(frame: 120, value: 130)]])

    @Test func samplesAtBeforeBetweenAndPastKeys() {
        let node = Self.rect("a", 10, 5, time: Self.slide)
        #expect(node.sampled(at: 0).frame.x == 10)
        #expect(node.sampled(at: -30).frame.x == 10)
        #expect(node.sampled(at: 60).frame.x == 70)
        #expect(node.sampled(at: 120).frame.x == 130)
        #expect(node.sampled(at: 400).frame.x == 130)
        #expect(node.sampled(at: 60).frame.y == 5, "an unkeyed property keeps its rest value")
        #expect(node.frame.x == 10, "sampling never writes the rest pose")
    }

    @Test func easingApplies() {
        let held = Self.rect("a", 10, 5, time: DesignNodeTime(tracks: [.x: [
            Keyframe(frame: 0, value: 10, easing: .hold), Keyframe(frame: 120, value: 130)]]))
        #expect(held.sampled(at: 60).frame.x == 10)
        #expect(held.sampled(at: 120).frame.x == 130)
        let eased = Self.rect("a", 10, 5, time: DesignNodeTime(tracks: [.x: [
            Keyframe(frame: 0, value: 10, easing: .easeIn), Keyframe(frame: 120, value: 130)]]))
        #expect(eased.sampled(at: 60).frame.x < 70, "ease-in sits behind the linear midpoint")
    }

    @Test func eachPropertyReadsItsOwnTrack() {
        let node = Self.rect("a", 10, 5, time: DesignNodeTime(tracks: [
            .y: [Keyframe(frame: 0, value: 5), Keyframe(frame: 100, value: 105)],
            .opacity: [Keyframe(frame: 0, value: 1), Keyframe(frame: 100, value: 0)],
        ]))
        let shown = node.sampled(at: 50)
        #expect(shown.frame.x == 10)
        #expect(shown.frame.y == 55)
        #expect(shown.opacity == 0.5)
    }

    @Test func aSubtreeMovesByItsKeyedParentsDelta() {
        let still = Self.rect("still", 100, 100)
        let keyed = Self.rect("keyed", 200, 100, time: DesignNodeTime(tracks: [
            .x: [Keyframe(frame: 0, value: 200), Keyframe(frame: 100, value: 300)]]))
        var frame = DesignNode(id: "f", name: "f", kind: .frame, frame: DesignRect(x: 0, y: 0, width: 500, height: 500),
                               children: [still, keyed])
        frame.time = DesignNodeTime(tracks: [.x: [Keyframe(frame: 0, value: 0), Keyframe(frame: 100, value: 20)]])
        let shown = frame.sampled(at: 50)
        #expect(shown.frame.x == 10)
        #expect(shown.children[0].frame.x == 110, "a still child moves with its parent")
        #expect(shown.children[1].frame.x == 260, "a keyed child adds its own delta to its parent's")
        #expect(shown.children[1].frame.y == 100)
    }

    @Test func aStillNodeSamplesToItself() {
        let page = DesignFixtures.cards.pages[0]
        #expect(page.sampled(at: 60) == page)
        #expect(page.nodes[0].sampled(at: 0) == page.nodes[0])
    }

    @Test func tracksAreSortedAndEmptyOnesDropped() {
        let time = DesignNodeTime(tracks: [.x: [Keyframe(frame: 120, value: 130), Keyframe(frame: 0, value: 10)], .y: []])
        #expect(time.tracks[.x]?.map(\.frame) == [0, 120])
        #expect(time.tracks[.y] == nil)
        #expect(DesignNodeTime(tracks: [.opacity: []]).isEmpty)
        var node = Self.rect("a", 0, 0)
        node.time = DesignNodeTime()
        #expect(node.time == nil, "a time with no keys leaves the node still")
    }

    @Test func roundTripsThroughTheFile() throws {
        let node = Self.rect("a", 10, 5, time: DesignNodeTime(tracks: [
            .x: [Keyframe(frame: 0, value: 10, easing: .easeOut), Keyframe(frame: 120, value: 130)],
            .opacity: [Keyframe(frame: 30, value: 0.5, easing: .hold)],
        ]))
        let data = try JSONEncoder().encode(node)
        #expect(try JSONDecoder().decode(DesignNode.self, from: data) == node)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains(#""tracks":{"#), "tracks save as an object keyed by property name")
    }

    @Test func decodingSortsATrack() throws {
        let json = #"{"tracks":{"x":[{"frame":120,"value":130,"easing":{"linear":{}}},{"frame":0,"value":10,"easing":{"linear":{}}}]}}"#
        let time = try JSONDecoder().decode(DesignNodeTime.self, from: Data(json.utf8))
        #expect(time.tracks[.x]?.map(\.frame) == [0, 120])
    }

    @Test func aStillNodeWritesNoTimeKey() throws {
        let json = String(decoding: try JSONEncoder().encode(Self.rect("a", 0, 0)), as: UTF8.self)
        #expect(!json.contains("time"))
    }

    @Test func anUnknownPropertyIsRefusedNotDropped() {
        let json = #"{"tracks":{"width":[{"frame":0,"value":1,"easing":{"linear":{}}}]}}"#
        #expect(throws: (any Error).self) { try JSONDecoder().decode(DesignNodeTime.self, from: Data(json.utf8)) }
    }

    @Test func aCopyKeepsTheKeys() {
        let node = Self.rect("a", 10, 5, time: Self.slide)
        #expect(DesignNode(id: "b", copying: node).time == Self.slide)
    }

    @Test func documentTimeDefaultsTo60FpsFor300Frames() {
        let time = DesignWorkspace().time
        #expect(time.rate == FrameRate(whole: 60))
        #expect(time.durationFrames == 300)
    }

    @Test func aDocumentWithNoKeyedNodeIsStill() {
        #expect(DesignFixtures.cards.isStill)
        #expect(DesignFixtures.empty.isStill)
        #expect(!DesignFixtures.animated(50).isStill)
        #expect(!DesignFixtures.keyedCrowd.isStill, "keys only on children still make the document animated")
    }

    @Test func animatedFixtureShowsTheSpikeValuesAtFrame60() throws {
        let page = try #require(DesignFixtures.animated(50).pages.first)
        #expect(page.nodes[0].children.count == 50)
        let node2 = try #require(page.sampled(at: 60).nodes[0].children.first)
        #expect(node2.id == "node-2")
        #expect(node2.frame.x == 47)
        #expect(node2.frame.y == 40)
        #expect(abs(node2.opacity - 0.65) < 1e-9)
        #expect(DesignFixtures.animated(500).pages[0].nodes[0].children.count == 500)
        #expect(!DesignFixtures.names.contains("animated"), "no journey launch argument changes")
    }

    @Test func keyedCrowdKeysOnlyTheRectangles() throws {
        let frame = try #require(DesignFixtures.keyedCrowd.pages.first?.nodes.first)
        #expect(frame.time == nil)
        #expect(frame.children.filter { $0.kind == .rectangle }.allSatisfy { $0.time != nil })
        #expect(frame.children.filter { $0.kind == .text }.allSatisfy { $0.time == nil })
    }

    @Test func aStillDocumentSavesByteForByteAsBefore() throws {
        let data = try LiveFiling().encode(DesignDocument(pages: DesignFixtures.cards.pages))
        #expect(String(decoding: data, as: UTF8.self) == Self.cardsVersion1)
    }

    /// `cards` saved through LiveFiling on origin/dev b0c081a61b, before node time existed.
    static let cardsVersion1 = #"{"pages":[{"frameHeight":1024,"frameWidth":1440,"id":"page-1","name":"Page 1","nodes":[{"children":[{"children":[],"cornerRadius":0,"fill":{"blue":217,"green":217,"red":217},"frame":{"height":80,"width":100,"x":100,"y":100},"id":"node-2","isHidden":false,"isLocked":false,"kind":"rectangle","name":"A","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}},{"children":[],"cornerRadius":0,"fill":{"blue":217,"green":217,"red":217},"frame":{"height":80,"width":200,"x":300,"y":140},"id":"node-3","isHidden":false,"isLocked":false,"kind":"rectangle","name":"B","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}},{"children":[],"cornerRadius":0,"fill":{"blue":217,"green":217,"red":217},"frame":{"height":120,"width":100,"x":700,"y":100},"id":"node-4","isHidden":false,"isLocked":false,"kind":"rectangle","name":"C","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}},{"children":[],"cornerRadius":0,"fill":{"blue":0,"green":0,"red":0},"frame":{"height":32,"width":200,"x":100,"y":40},"id":"node-5","isHidden":false,"isLocked":false,"kind":"text","name":"Title","opacity":1,"text":"Title","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}},{"children":[{"children":[],"cornerRadius":0,"fill":{"blue":217,"green":217,"red":217},"frame":{"height":100,"width":100,"x":900,"y":400},"id":"node-7","isHidden":false,"isLocked":false,"kind":"ellipse","name":"E1","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}},{"children":[],"cornerRadius":0,"fill":{"blue":217,"green":217,"red":217},"frame":{"height":100,"width":100,"x":1100,"y":400},"id":"node-8","isHidden":false,"isLocked":false,"kind":"ellipse","name":"E2","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}}],"cornerRadius":0,"fill":{"blue":217,"green":217,"red":217},"frame":{"height":100,"width":300,"x":900,"y":400},"id":"node-6","isHidden":false,"isLocked":false,"kind":"group","name":"Pair","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}},{"children":[],"cornerRadius":0,"fill":{"blue":217,"green":217,"red":217},"frame":{"height":100,"width":100,"x":400,"y":600},"id":"node-9","isHidden":false,"isLocked":true,"kind":"rectangle","name":"Locked","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}},{"children":[],"cornerRadius":0,"fill":{"blue":217,"green":217,"red":217},"frame":{"height":100,"width":100,"x":600,"y":600},"id":"node-10","isHidden":true,"isLocked":false,"kind":"rectangle","name":"Hidden","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}}],"cornerRadius":0,"fill":{"blue":255,"green":255,"red":255},"frame":{"height":1024,"width":1440,"x":0,"y":0},"id":"node-1","isHidden":false,"isLocked":false,"kind":"frame","name":"Desktop","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}}]}],"version":1}"#
}
