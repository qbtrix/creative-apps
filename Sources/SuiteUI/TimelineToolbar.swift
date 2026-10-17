// TimelineToolbar.swift: the timeline strip's own toolbar row, shown when the
// host passes `toolbar: true` (timeline packet, TL-17). It sits in the 36 pt
// the strip's ideal height already holds for it (TL-7): a "Zoom" bar
// (StudioScrubRow) from fit (1) to TimelineZoom's clamp for the host's
// frameWidth, and a Fit chip that sets 1. Each control is registered in
// suite.controls with its tooltip as the reason; the bar is disabled when the
// host is already 64 pt per frame wide. Values in, a closure out: the strip
// owns the zoom. TL-18: "Frames" / "Timecode" chips call onUnit (Timecode is
// disabled without a frame rate) and "Work Area" calls onWorkArea(0...duration
// or nil). TimelineToolbarControls holds ids, help, sizes and what each sends.
import SwiftUI

/// The toolbar's controls as plain values (TimelineToolbarTests).
struct TimelineToolbarControls: Equatable, Sendable {
    let frameWidth: Double
    /// The last frame: the Work Area chip turns on over 0...duration.
    var duration: Int = 0
    /// The host's frame rate; 0 or less can't show timecode.
    var fps: Int = 0

    /// What Fit sets: the whole timeline in view.
    static let fitZoom: Double = 1
    /// The bar's tooltip: ScrubField shows its label as its help.
    static let zoomHelp = "Zoom"
    static let fitHelp = "Fit the whole timeline in view (Command-0)"
    static let zoomHeight = SuiteSize.studioRow
    static let fitHeight = SuiteSize.chip
    /// The unit and work-area chips: 28 pt.
    static let chipHeight = SuiteSize.chip

    /// The bar's range: fit up to 64 pt per frame.
    var barRange: ClosedRange<Double> {
        TimelineZoom.range(frameWidth: frameWidth)
    }

    var zoomEntry: ControlEntry {
        let range = barRange
        let canZoom = range.upperBound > range.lowerBound
        return ControlEntry(id: "suite.timeline.zoom", enabled: canZoom, reason: Self.zoomHelp)
    }

    var fitEntry: ControlEntry {
        ControlEntry(id: "suite.timeline.fit", enabled: true, reason: Self.fitHelp)
    }

    var framesHelp: String { "Show time in frames" }
    var timecodeHelp: String {
        fps > 0 ? "Show time as timecode: minutes, seconds and frames" : "Timecode needs the document's frame rate"
    }
    var workAreaHelp: String { "Show the work area on the ruler; drag its handles to set it" }

    var framesEntry: ControlEntry {
        ControlEntry(id: "suite.timeline.unit.frames", enabled: true, reason: framesHelp)
    }

    var timecodeEntry: ControlEntry {
        ControlEntry(id: "suite.timeline.unit.timecode", enabled: fps > 0, reason: timecodeHelp)
    }

    var workAreaEntry: ControlEntry {
        ControlEntry(id: "suite.timeline.workarea", enabled: true, reason: workAreaHelp)
    }

    /// What the Work Area chip sends from `current`: the whole timeline when
    /// it turns on, nil when it turns off.
    func workAreaAfterToggle(current: ClosedRange<Int>?) -> ClosedRange<Int>? {
        guard current == nil else { return nil }
        return 0...max(duration, 0)
    }
}

/// The chips the toolbar shows after Fit.
enum TimelineToolbarChip: Hashable, Sendable { case frames, timecode, workArea }

/// The toolbar row; `onZoom` hears the zoom the bar or Fit asks for.
struct TimelineToolbar: View {
    let zoom: Double
    let controls: TimelineToolbarControls
    let unit: TimeUnit
    let workArea: ClosedRange<Int>?
    let onZoom: @MainActor (Double) -> Void
    let onUnit: @MainActor (TimeUnit) -> Void
    let onWorkArea: @MainActor (ClosedRange<Int>?) -> Void

    var body: some View {
        let zoomEntry = controls.zoomEntry
        let fitEntry = controls.fitEntry
        HStack(spacing: SuiteSpacing.s) {
            StudioScrubRow(label: "Zoom", value: zoom, range: controls.barRange, step: 0.1, onChange: onZoom)
                .frame(width: SuiteSize.inspectorWidth.ideal, height: TimelineToolbarControls.zoomHeight)
                .disabled(!zoomEntry.enabled)
                .help(TimelineToolbarControls.zoomHelp)
                .suiteControl(id: zoomEntry.id, enabled: zoomEntry.enabled, reason: zoomEntry.reason)
            Button("Fit") { onZoom(TimelineToolbarControls.fitZoom) }
                .buttonStyle(SuiteChipStyle(kind: .chip, isOn: zoom == TimelineToolbarControls.fitZoom))
                .frame(height: TimelineToolbarControls.fitHeight)
                .help(TimelineToolbarControls.fitHelp)
                .suiteControl(id: fitEntry.id, enabled: fitEntry.enabled, reason: fitEntry.reason)
            chip(.frames, title: "Frames", isOn: unit == .frames || controls.fps <= 0, entry: controls.framesEntry)
            chip(.timecode, title: "Timecode", isOn: unit == .timecode && controls.fps > 0, entry: controls.timecodeEntry)
            chip(.workArea, title: "Work Area", isOn: workArea != nil, entry: controls.workAreaEntry)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SuiteSpacing.s)
        .frame(height: SuiteSize.timelineSlotToolbar)
    }

    /// One chip in its own ChipRow, so each carries its own help and entry.
    private func chip(_ id: TimelineToolbarChip, title: String, isOn: Bool, entry: ControlEntry) -> some View {
        ChipRow([ChipItem(id: id, title: title, isOn: isOn)]) { chip in
            switch chip {
            case .frames: onUnit(.frames)
            case .timecode: onUnit(.timecode)
            case .workArea: onWorkArea(controls.workAreaAfterToggle(current: workArea))
            }
        }
        .frame(height: TimelineToolbarControls.chipHeight)
        .disabled(!entry.enabled)
        .help(entry.reason ?? "")
        .suiteControl(id: entry.id, enabled: entry.enabled, reason: entry.reason)
    }
}
