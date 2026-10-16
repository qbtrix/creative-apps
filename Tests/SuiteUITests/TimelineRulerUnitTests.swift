// TimelineRulerUnitTests.swift: the strip's units and work area (timeline
// packet, TL-18). In timecode the ruler labels read "00:01:00" style on whole
// seconds and never overlap at widths 320, 640 and 1,280 (QB-S21); the Work
// Area chip sends 0...duration, then nil; the chips register with reasons
// equal to their help, 28 pt; a handle drag sends one span on release,
// clamped by trimmed, and nothing after Escape. No view is hosted. macOS only.
@testable import SuiteUI
import Testing

@Suite struct TimelineRulerUnitTests {
    /// Ten seconds at 24 fps, fit to `width`.
    private func labels(width: Double, unit: TimeUnit) -> [TimelineRulerLabel] {
        let rules = TimelineRulerLabels(mapping: FrameMapping(duration: 240, frameWidth: width / 240), unit: unit, fps: 24)
        return rules.placed(rules.frames(visibleX: 0...width))
    }

    @Test func timecodeLabelsSitOnWholeSecondsAndNeverOverlap() {
        for width in [320.0, 640, 1_280] {
            let placed = labels(width: width, unit: .timecode)
            #expect(placed.count >= 2, "width \(width)")
            for label in placed {
                #expect(label.frame % 24 == 0 && label.text.count == 8 && label.text.hasSuffix(":00"), "\(label.text)")
                #expect(label.text == TimelineTime.label(frame: label.frame, fps: 24, unit: .timecode))
            }
            for (a, b) in zip(placed, placed.dropFirst()) {
                #expect(a.maxX <= b.minX, "width \(width): \(a.text) runs into \(b.text)")
            }
        }
        #expect(labels(width: 1_280, unit: .timecode).map(\.text).contains("00:01:00"))
        let frames = labels(width: 1_280, unit: .frames)
        #expect(frames.allSatisfy { $0.text == "\($0.frame)" } && frames.map(\.text).contains("20"))
    }

    @Test func theWorkAreaChipSendsTheWholeTimelineThenNil() {
        let controls = TimelineToolbarControls(frameWidth: 4, duration: 120)
        let on = controls.workAreaAfterToggle(current: nil)
        #expect(on == 0...120)
        #expect(controls.workAreaAfterToggle(current: on) == nil)
    }

    @Test func theUnitAndWorkAreaChipsRegisterWithReasonsEqualToTheirHelp() {
        let controls = TimelineToolbarControls(frameWidth: 4, duration: 120, fps: 24)
        let entries = [controls.framesEntry, controls.timecodeEntry, controls.workAreaEntry]
        #expect(entries.map(\.id) == ["suite.timeline.unit.frames", "suite.timeline.unit.timecode", "suite.timeline.workarea"])
        #expect(entries.map(\.reason) == [controls.framesHelp, controls.timecodeHelp, controls.workAreaHelp])
        #expect(entries.allSatisfy { $0.enabled && !($0.reason ?? "").isEmpty })
        #expect(TimelineToolbarControls.chipHeight == 28)
        // With no frame rate timecode can't show: its chip is disabled and says why.
        let noRate = TimelineToolbarControls(frameWidth: 4, duration: 120, fps: 0)
        #expect(!noRate.timecodeEntry.enabled && noRate.timecodeEntry.reason == noRate.timecodeHelp)
        #expect(noRate.timecodeHelp != controls.timecodeHelp)
    }

    @Test func aHandleDragSendsOneSpanOnReleaseClampedByTrimmed() {
        let mapping = FrameMapping(duration: 100, frameWidth: 10)
        var drag = TimelineWorkAreaDrag(start: 20...60, edge: .end)
        #expect(drag.move(toX: 50, mapping: mapping) && drag.span == 20...21)   // one frame kept
        let sameFrame = drag.move(toX: 52, mapping: mapping)   // a mutating call can't sit alone in #expect
        #expect(!sameFrame)
        let clamped = drag.move(toX: 5_000, mapping: mapping)
        #expect(clamped)
        #expect(drag.span == SuiteTimelineEditing().trimmed(20...60, edge: .end, to: 500, lastFrame: 100))
        #expect(drag.released() == 20...100)
        var start = TimelineWorkAreaDrag(start: 20...60, edge: .start)
        #expect(start.move(toX: -300, mapping: mapping) && start.released() == 0...60)
        var still = TimelineWorkAreaDrag(start: 20...60, edge: .start)
        _ = still.move(toX: 200, mapping: mapping)
        #expect(still.released() == nil)
    }

    @Test func escapeCancelsAHandleDragWithNothingSent() {
        let mapping = FrameMapping(duration: 100, frameWidth: 10)
        var drag = TimelineWorkAreaDrag(start: 20...60, edge: .end)
        _ = drag.move(toX: 800, mapping: mapping)
        drag.cancel()
        #expect(drag.span == 20...60 && !drag.move(toX: 900, mapping: mapping))
        #expect(drag.released() == nil)
    }

    @Test func aPressWithinEightPointsOfAHandleGrabsIt() {
        let geometry = TimelineWorkAreaGeometry(mapping: FrameMapping(duration: 100, frameWidth: 10), span: 20...60, scrollX: 0)
        let startX = tickX(geometry.mapping, 20), endX = tickX(geometry.mapping, 60)
        #expect(geometry.edge(atX: startX + 7) == .start && geometry.edge(atX: startX + 9) == nil)
        #expect(geometry.edge(atX: endX - 7) == .end && geometry.handleRect(.end).width == 16)
        #expect(geometry.barRect(width: 2_000).height == 6 && geometry.barRect(width: 2_000).maxY == SuiteSize.timelineRuler)
        #expect(geometry.contentX(endX) == 600)
    }
}
