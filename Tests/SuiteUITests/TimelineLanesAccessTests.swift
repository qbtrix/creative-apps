// TimelineLanesAccessTests.swift: TL-23 (timeline packet, acceptance row
// TL-23). Each key on the AppKit lanes is an accessibility child of
// TimelineLanesView with the lane's spoken value and TimelineLaneSpeech's key
// label, selected while picked, whose default action picks it alone, as
// TL-12's SwiftUI children do. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct TimelineLanesAccessTests {
    private static let mapping = FrameMapping(duration: 400, frameWidth: 4)
    private static let track = TimelineTrack(
        id: "badge", name: "Badge",
        keys: [TimelineKey(frame: 20, shape: .linear), TimelineKey(frame: 30, shape: .eased), TimelineKey(frame: 50, shape: .hold)],
        spans: [20...50], pickedFrames: [30])

    /// Every pick the host heard, as "id frame mode".
    @MainActor private final class Log {
        var picks: [String] = []
        var actions: TimelineLaneActions<String> {
            TimelineLaneActions(
                onSelectKeyframe: { _, _ in }, onSelectTrack: { _ in },
                onPickKeyframe: { id, frame, mode in self.picks.append("\(id) \(frame.map(String.init) ?? "nil") \(mode)") })
        }
    }

    /// A lanes view showing `track`, its pointer reporting to `log` when one is given.
    private func view(_ log: Log? = nil) -> TimelineLanesView {
        let view = TimelineLanesView(frame: NSRect(x: 0, y: 0, width: 1_800, height: SuiteSize.timelineLane))
        if let log {
            let pointer = TimelineLanePointer<String>()
            pointer.configure(
                track: Self.track, mapping: Self.mapping, playhead: 0, actions: log.actions,
                extras: TimelineLanePointerExtras(focus: nil, pill: .constant(nil), mark: nil))
            view.pointer = pointer
        }
        view.update([TimelineLaneDrawing(Self.track, mapping: Self.mapping)])
        return view
    }

    @Test func eachKeyIsAChildWithTheLanesSpokenValue() {
        let elements = view().keyElements()
        #expect(elements.map(\.key.child.frame) == [20, 30, 50])
        #expect(elements.map { $0.accessibilityLabel() } == [
            "Key at frame 20, linear", "Key at frame 30, eased", "Key at frame 50, hold",
        ])
        let spoken = TimelineLaneSpeech.value(of: Self.track)
        #expect(spoken == "Frames 20–50, 3 keyframes at 20, 30, 50")
        #expect(elements.allSatisfy { ($0.accessibilityValue() as? String) == spoken })
        #expect(elements.map { $0.accessibilityRole() } == [.button, .button, .button])
    }

    @Test func theViewListsItsKeysAsChildren() {
        let view = view()
        let children = view.accessibilityChildren() ?? []
        #expect(children.count == 3)
        #expect(children.allSatisfy { $0 is TimelineLaneKeyElement })
        #expect(view.isAccessibilityElement())
    }

    @Test func aKeyIsSelectedWhilePicked() {
        let picked = view().keyElements().filter { $0.isAccessibilitySelected() }.map(\.key.child.frame)
        #expect(picked == [30])
    }

    @Test func aKeySitsOverItsDiamond() {
        let keys = TimelineLanesAccess.keys(of: [TimelineLaneDrawing(Self.track, mapping: Self.mapping)], width: 1_800)
        let key = keys.first { $0.child.frame == 50 }
        #expect(key?.center == CGPoint(x: tickX(Self.mapping, 50), y: SuiteSize.timelineLane / 2))
        #expect(key?.token.width == SuiteSize.timelineKeyframeHit)
    }

    @Test func theDefaultActionPicksTheKeyAlone() {
        let log = Log()
        let elements = view(log).keyElements()
        let key = elements.first { $0.key.child.frame == 50 }
        let pressed = key?.accessibilityPerformPress() ?? false
        #expect(pressed)
        #expect(log.picks.last == "badge 50 replace")
        #expect(!log.picks.isEmpty && log.picks.allSatisfy { $0 == "badge 50 replace" })
    }

    @Test func withNoPointerTheActionDoesNothing() {
        let key = view().keyElements().first
        let pressed = key?.accessibilityPerformPress() ?? true
        #expect(!pressed)
    }

    @Test func onlyVisibleKeysAndOneEachSideGetAChild() {
        let keys = (0..<40).map { TimelineKey(frame: $0 * 10, shape: .linear) }
        let long = TimelineTrack(id: "a", name: "A", keys: keys)
        let lane = TimelineLaneDrawing(long, mapping: Self.mapping)
        let x0 = tickX(Self.mapping, 100), x1 = tickX(Self.mapping, 200)
        let shown = TimelineLanesAccess.keys(of: [lane], width: 1_800, visibleX: x0...x1).map(\.child.frame)
        #expect(shown == Array(stride(from: 90, through: 210, by: 10)))
    }
}
