// TimelineAccessTests.swift: TL-12's keyboard and VoiceOver rules (timeline
// packet, acceptance row TL-12). A lane's value reads its spans, then its keys
// (#772); each key child reads its frame and shape, its default action picks
// it alone, and it is selected while picked; → and ← step the pick along its
// track and stop at either end. macOS only.
import Foundation
import SwiftUI
@testable import SuiteUI
import Testing

@MainActor @Suite struct TimelineAccessTests {
    private static let badge = TimelineTrack(
        id: "badge", name: "Badge", keys: [50, 20, 30].map { TimelineKey(frame: $0, shape: .linear) },
        spans: [20...50])
    private static let ball = TimelineTrack(
        id: "ball", name: "Ball",
        keys: [
            TimelineKey(frame: 0, shape: .linear), TimelineKey(frame: 12, shape: .linear),
            TimelineKey(frame: 24, shape: .eased), TimelineKey(frame: 36, shape: .hold),
        ],
        pickedFrames: [12], isSelected: true)

    private static func track(_ id: String, keys: [Int], picked: Set<Int> = [], selected: Bool = false)
        -> TimelineTrack<String>
    {
        TimelineTrack(
            id: id, name: id, keys: keys.map { TimelineKey(frame: $0, shape: .linear) },
            pickedFrames: picked, isSelected: selected)
    }

    @Test func aLaneValueReadsItsSpansThenItsKeys() {
        #expect(TimelineLaneSpeech.value(of: Self.badge) == "Frames 20–50, 3 keyframes at 20, 30, 50")
        #expect(TimelineLaneSpeech.value(of: Self.track("a", keys: [])) == "No keyframes")
        #expect(TimelineLaneSpeech.value(of: Self.track("a", keys: [12])) == "1 keyframe at 12")
    }

    @Test func aKeyChildReadsItsFrameAndShapeAndFollowsThePick() {
        let children = TimelineLaneSpeech.children(of: Self.ball)
        #expect(children.map(\.frame) == [0, 12, 24, 36])
        #expect(children.first { $0.frame == 24 }?.label == "Key at frame 24, eased")
        #expect(children.first { $0.frame == 36 }?.label == "Key at frame 36, hold")
        #expect(children.filter(\.picked).map(\.frame) == [12])
    }

    @Test func aKeyChildsDefaultActionPicksItAlone() {
        var calls: [String] = []
        let picker = TimelineKeyPicker()
        picker.update { (id: String, frame: Int?, mode: PickMode) in
            calls.append("pick \(id) \(frame.map(String.init) ?? "nil") \(mode.rawValue)")
        }
        TimelineLaneSpeech.activate(24, on: Self.ball, picker: picker)
        #expect(calls == ["pick ball 24 replace"])
        TimelineLaneSpeech.activate(36, on: Self.ball, picker: nil)
        #expect(calls == ["pick ball 24 replace"])
    }

    @Test func rightFromTwelvePicksTwentyFourAndLeftAtZeroDoesNothing() {
        #expect(TimelineArrowStep.direction(.rightArrow) == 1)
        #expect(TimelineArrowStep.direction(.leftArrow) == -1)
        #expect(TimelineArrowStep.step(for: .rightArrow, tracks: [Self.ball]) == .pick("ball", 24))
        #expect(TimelineArrowStep.step(for: .leftArrow, tracks: [Self.ball]) == .pick("ball", 0))
        let atZero = Self.track("ball", keys: [0, 12, 24], picked: [0], selected: true)
        #expect(TimelineArrowStep.step(for: .leftArrow, tracks: [atZero]) == .atEnd)
        let atLast = Self.track("ball", keys: [0, 12, 24], picked: [24], selected: true)
        #expect(TimelineArrowStep.step(for: .rightArrow, tracks: [atLast]) == .atEnd)
    }

    @Test func withNoPickAnArrowPicksTheSelectedTracksFirstKey() {
        let other = Self.track("a", keys: [5])
        let selected = Self.track("b", keys: [30, 10, 20], selected: true)
        #expect(TimelineArrowStep.step(for: .rightArrow, tracks: [other, selected]) == .pick("b", 10))
        #expect(TimelineArrowStep.step(for: .leftArrow, tracks: [other, selected]) == .pick("b", 10))
        #expect(TimelineArrowStep.step(for: .rightArrow, tracks: [other]) == .ignored)
    }

    @Test func aPickOnTheSelectedTrackLeadsAndAGroupStepsFromItsEdge() {
        let picked = Self.track("a", keys: [0, 10], picked: [0])
        let selected = Self.track("b", keys: [0, 10, 20, 30], picked: [10, 20], selected: true)
        #expect(TimelineArrowStep.step(for: .rightArrow, tracks: [picked, selected]) == .pick("b", 30))
        #expect(TimelineArrowStep.step(for: .leftArrow, tracks: [picked, selected]) == .pick("b", 0))
        #expect(TimelineArrowStep.step(for: .rightArrow, tracks: [picked, Self.track("c", keys: [1])]) == .pick("a", 10))
        #expect(TimelineArrowStep.step(for: .upArrow, tracks: [selected]) == .ignored)
    }
}
