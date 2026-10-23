// FrameRateMenuTests.swift: FR-u (frame-rates packet, FR-5 and FR-6). The
// shared FrameRateMenu lists SuiteKernel's FrameRate.common in order, each
// titled as the time.rates commands title it ("29.97 fps"), with the bound
// rate checked; the timeline readout shows timecode at the document's rate
// through SuiteKernel's Timecode (";" before the frames at a drop-frame rate).
// The strip's pill and ruler read the same string at the host's rate (#4359);
// the readout's tooltip names what it counts (#4360); the gallery captions it
// "Playhead", "(drop-frame)" at a drop rate, its value in the shared status
// pill (#4599, #4600); the toolbar placement draws a raised chip (#4601); the
// ruler and pill redraw when only the rate changes (#4603).
import Foundation
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@Suite struct FrameRateMenuTests {
    private static let ntsc = FrameRate(numerator: 30_000, denominator: 1_001)

    @Test func listsTheNineCommonRatesInOrder() {
        let items = FrameRateMenu.items(checked: FrameRate(whole: 24))
        #expect(items.map(\.rate) == FrameRate.common)
        #expect(items.map(\.title) == [
            "12 fps", "23.976 fps", "24 fps", "25 fps", "29.97 fps", "30 fps", "50 fps", "59.94 fps", "60 fps",
        ])
    }

    @Test func titlesNTSCAsTheCommandsDo() {
        let item = FrameRateMenu.items(checked: Self.ntsc).first { $0.rate == Self.ntsc }
        #expect(item?.title == "29.97 fps")
        #expect(item?.title == Self.ntsc.description)
    }

    @Test(arguments: FrameRate.common) func checksOnlyTheBoundRate(rate: FrameRate) {
        let checked = FrameRateMenu.items(checked: rate).filter(\.isChecked)
        #expect(checked.map(\.rate) == [rate])
    }

    @Test func aRateOffTheListChecksNothing() {
        #expect(FrameRateMenu.items(checked: FrameRate(whole: 15)).allSatisfy { !$0.isChecked })
    }

    @MainActor @Test func pickingARateReportsIt() {
        let log = PickLog()
        let menu = FrameRateMenu(rate: FrameRate(whole: 24)) { log.picked.append($0) }.menu
        menu.pick.wrappedValue = Self.ntsc
        #expect(log.picked == [FrameRate(numerator: 30_000, denominator: 1_001)])
    }

    @MainActor private final class PickLog {
        var picked: [FrameRate] = []
    }

    /// #4362: the rate menu draws InspectorPickerRow's value menu, not a bordered pop-up of its own.
    @MainActor @Test func drawsTheInspectorPickerRowsValueMenu() {
        let options = FrameRate.common.map { InspectorOption(id: $0, title: $0.description) }
        let row: InspectorValueMenu<FrameRate> = InspectorPickerRow(
            "Frame Rate", options: options, selection: Self.ntsc) { _ in }.menu
        let menu: InspectorValueMenu<FrameRate> = FrameRateMenu(rate: Self.ntsc) { _ in }.menu
        #expect(menu.label == row.label)
        #expect(menu.options == row.options)
        #expect(menu.selection == row.selection)
        #expect(menu.choiceTitle == "29.97 fps")
        #expect(menu.choiceTitle == row.choiceTitle)
    }

    @MainActor @Test func aRateOffTheListStillTitlesTheMenu() {
        #expect(FrameRateMenu(rate: FrameRate(whole: 15)) { _ in }.menu.choiceTitle == "15 fps")
    }

    @Test func readoutShowsDropFrameTimecodeAtNTSC() {
        #expect(TimelineTime.label(frame: 30, rate: Self.ntsc, unit: .timecode) == "00:00:01;00")
        #expect(TimelineTime.label(frame: 1_800, rate: Self.ntsc, unit: .timecode) == "00:01:00;02")
    }

    @Test func readoutShowsNonDropTimecodeAtWholeRates() {
        #expect(TimelineTime.label(frame: 30, rate: FrameRate(whole: 30), unit: .timecode) == "00:00:01:00")
        #expect(TimelineTime.label(frame: 48, rate: FrameRate(whole: 24), unit: .timecode) == "00:00:02:00")
    }

    @Test func readoutInFramesIsTheFrameNumber() {
        #expect(TimelineTime.label(frame: 30, rate: Self.ntsc, unit: .frames) == "30")
    }

    @MainActor @Test func pillAndRulerReadTheReadoutAtNTSC() {
        let mapping = FrameMapping(duration: 9_999, frameWidth: 2)
        let caption = TimelineTime.label(frame: 1_800, rate: Self.ntsc, unit: .timecode)
        let playhead = TimelinePlayhead(
            mapping: mapping, playhead: 1_800, unit: .timecode, fps: Self.ntsc.nominal, scroll: .zero, keys: [],
            rate: Self.ntsc, onScrub: { _ in })
        #expect(playhead.label == "00:01:00;02")
        let rules = TimelineRulerLabels(mapping: mapping, unit: .timecode, fps: Self.ntsc.nominal, rate: Self.ntsc)
        #expect(rules.text(1_800) == caption)
        let whole = TimelineRulerLabels(mapping: mapping, unit: .timecode, fps: 24, rate: FrameRate(whole: 24))
        #expect(whole.text(360) == "00:00:15:00")
    }

    @Test func readoutHelpNamesDropFrameOnlyAtDropRates() {
        let ntsc = TimelineTime.readoutHelp(rate: Self.ntsc)
        #expect(ntsc.contains("drop-frame") && ntsc.contains("frames") && ntsc.contains("29.97 fps"))
        let film = TimelineTime.readoutHelp(rate: FrameRate(whole: 24))
        #expect(!film.contains("drop-frame") && film.contains("frames"))
    }

    /// #4600: the visible caption names drop-frame at a drop rate only.
    @Test func readoutCaptionNamesDropFrameOnlyAtDropRates() {
        #expect(TimelineTime.readoutCaption(rate: Self.ntsc).contains("drop-frame"))
        #expect(TimelineTime.readoutCaption(rate: FrameRate(numerator: 60_000, denominator: 1_001)).contains("drop-frame"))
        let whole = TimelineTime.readoutCaption(rate: FrameRate(whole: 30))
        #expect(!whole.contains("drop-frame") && !whole.contains("DF"))
        #expect(whole == "Playhead", "the caption repeats the unit chip's title")
    }

    /// #4601: the toolbar placement draws the raised chip at compactControl; a row keeps the value menu.
    @MainActor @Test func toolbarPlacementDrawsTheChipAtCompactSize() throws {
        let toolbar = FrameRateMenu(rate: Self.ntsc, placement: .toolbar) { _ in }
        #expect(toolbar.placement == .toolbar)
        #expect(toolbar.controlSize == SuiteSize.compactControl)
        #expect(FrameRateMenu(rate: Self.ntsc) { _ in }.placement == .row)
        let source = try Self.source("Sources/SuiteUI/FrameRateMenu.swift")
        let start = try #require(source.range(of: "private var chip: some View {"), "the chip moved; point this test at it")
        let chip = source[start.upperBound...]
        #expect(chip.contains(".buttonStyle(SuiteChipStyle(kind: .chip, isOn: false))"))
        #expect(chip.contains(".menuStyle(.button)"))
        #expect(source.contains("case .toolbar: chip"))
    }

    /// #4603: at fps 30, 30 and 29.97 differ only by rate; the ruler and the pill must redraw for it.
    @MainActor @Test func rulerAndPillRedrawWhenOnlyTheRateChanges() {
        let mapping = FrameMapping(duration: 9_999, frameWidth: 2)
        let whole = FrameRate(whole: 30)
        #expect(whole.nominal == Self.ntsc.nominal)
        let marks30 = TimelineRulerMarks(mapping: mapping, visibleX: 0...800, unit: .timecode, fps: 30, rate: whole)
        let marksNTSC = TimelineRulerMarks(mapping: mapping, visibleX: 0...800, unit: .timecode, fps: 30, rate: Self.ntsc)
        #expect(marks30 != marksNTSC, "the ruler keeps 00:01:00:00 at 29.97")
        #expect(marks30 == TimelineRulerMarks(mapping: mapping, visibleX: 0...800, unit: .timecode, fps: 30, rate: whole))
        let pill = { (rate: FrameRate) in
            TimelinePlayhead(
                mapping: mapping, playhead: 1_800, unit: .timecode, fps: 30, scroll: .zero, keys: [], rate: rate,
                onScrub: { _ in })
        }
        #expect(pill(whole) != pill(Self.ntsc), "the pill keeps 00:01:00:00 at 29.97")
        #expect(pill(whole) == pill(whole))
    }

    /// A source check: the gallery's readout is captioned "Playhead" in the shared pill, never a capsule of its own.
    @Test func galleryReadoutIsTheSharedPillCaptionedPlayhead() throws {
        let source = try Self.source("Sources/SuiteUI/Gallery/GalleryTimeline.swift")
        let start = try #require(source.range(of: "private func timecodeReadout("), "the readout moved; point this test at it")
        let end = try #require(source.range(of: "private func frameField(", range: start.upperBound..<source.endIndex))
        let body = source[start.upperBound..<end.lowerBound]
        #expect(body.contains("unit: .timecode"))
        #expect(body.contains("Text(verbatim: TimelineTime.readoutCaption(rate: rate))"))
        #expect(body.contains("StatusPillFace(.plain) {\n                Text(verbatim: timecode)\n                    .font(SuiteFont.monospacedDigits)"))
        #expect(!body.contains("Text(\"Timecode\")"), "the readout repeats the unit chip's title")
        #expect(!source.contains("Capsule().fill"), "the gallery draws a capsule of its own")
        #expect(body.contains(".help(TimelineTime.readoutHelp(rate: rate))"))
        #expect(body.contains(".accessibilityLabel(Text(verbatim: TimelineTime.readoutHelp(rate: rate)))"))
        #expect(source.contains("FrameRateMenu(rate: rate, placement: .toolbar)"))
    }

    /// The repo file at `path`.
    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }
}
