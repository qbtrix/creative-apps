// TimelineToolbar.swift: the timeline strip's own toolbar row, shown when the
// host passes `toolbar: true` (timeline packet, TL-17). It sits in the 36 pt
// the strip's ideal height already holds for it (TL-7): a "Zoom" bar
// (StudioScrubRow) from fit (1) to TimelineZoom's clamp for the host's
// frameWidth, and a Fit chip that sets 1. Each control is registered in
// suite.controls with its tooltip as the reason; the bar is disabled when the
// host is already 64 pt per frame wide. Values in, a closure out: the strip
// owns the zoom. TimelineToolbarControls holds the ids, help, sizes and the
// bar's range with no view (TimelineToolbarTests). TL-18 adds the unit and
// work-area chips here.
import SwiftUI

/// The toolbar's controls as plain values (TimelineToolbarTests).
struct TimelineToolbarControls: Equatable, Sendable {
    let frameWidth: Double

    /// What Fit sets: the whole timeline in view.
    static let fitZoom: Double = 1
    /// The bar's tooltip: ScrubField shows its label as its help.
    static let zoomHelp = "Zoom"
    static let fitHelp = "Fit the whole timeline in view (Command-0)"
    static let zoomHeight = SuiteSize.studioRow
    static let fitHeight = SuiteSize.chip

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
}

/// The toolbar row; `onZoom` hears the zoom the bar or Fit asks for.
struct TimelineToolbar: View {
    let zoom: Double
    let controls: TimelineToolbarControls
    let onZoom: @MainActor (Double) -> Void

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
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SuiteSpacing.s)
        .frame(height: SuiteSize.timelineSlotToolbar)
    }
}
