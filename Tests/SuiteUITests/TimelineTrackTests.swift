// TimelineTrackTests.swift: the timeline's track data (TL-3). The old
// `keyframes:` init makes linear keys and reads back the same frames, so every
// existing call draws as before; the new init keeps its keys' shapes and the
// picked frames, which never change what `keyframes` reads. That the old
// TimelineStrip and TimelineTrack calls compile untouched is the macOS build
// of HaloTimelineView and SuiteTimelineSnapshots. No SwiftUI. macOS only.
import SuiteUI
import Testing

@Suite struct TimelineTrackTests {
    @Test func oldInitMakesLinearKeysWithTheSameFrames() {
        let track = TimelineTrack(id: "position", name: "Position", keyframes: [0, 12])
        #expect(track.keys == [TimelineKey(frame: 0, shape: .linear), TimelineKey(frame: 12, shape: .linear)])
        #expect(track.keyframes == [0, 12])
        #expect(track.pickedFrames.isEmpty)
    }

    @Test func oldInitKeepsSpansAndSelection() {
        let track = TimelineTrack(id: "logo", name: "Logo", keyframes: [24], spans: [18...90], isSelected: true)
        #expect(track.spans == [18...90])
        #expect(track.isSelected)
        #expect(track.keyframes == [24])
    }

    @Test func newInitKeepsShapesAndPickedFrames() {
        let keys = [
            TimelineKey(frame: 0, shape: .eased), TimelineKey(frame: 12, shape: .hold), TimelineKey(frame: 30, shape: .linear),
        ]
        let track = TimelineTrack(id: 1, name: "Opacity", keys: keys, spans: [0...40], pickedFrames: [12], isSelected: true)
        #expect(track.keys == keys)
        #expect(track.keyframes == [0, 12, 30])
        #expect(track.pickedFrames == [12])
        #expect(track.spans == [0...40])
        #expect(track.isSelected)
    }

    @Test func pickedFramesTellTracksApart() {
        let keys = [TimelineKey(frame: 6, shape: .linear)]
        let none = TimelineTrack(id: "r", name: "Rotation", keys: keys)
        let picked = TimelineTrack(id: "r", name: "Rotation", keys: keys, pickedFrames: [6])
        #expect(none.pickedFrames.isEmpty)
        #expect(none != picked)
        #expect(picked.keyframes == [6])
    }
}
