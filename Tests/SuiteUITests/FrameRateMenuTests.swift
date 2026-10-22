// FrameRateMenuTests.swift: FR-u (frame-rates packet, FR-5 and FR-6). The
// shared FrameRateMenu lists SuiteKernel's FrameRate.common in order, each
// titled as the time.rates commands title it ("29.97 fps"), with the bound
// rate checked; the timeline readout shows timecode at the document's rate
// through SuiteKernel's Timecode (";" before the frames at a drop-frame rate).
// The strip's pill and ruler read the same string at the host's rate (#4359);
// the readout's tooltip names what it counts (#4360) and the gallery sets it
// in SuiteFont.timecode, primary text, labelled "Timecode" (#4363, #4367, #4368).
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

    /// A source check: the gallery's timecode readout is set as a timecode value, not a caption.
    @Test func galleryReadoutIsSetInTheTimecodeFace() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "Sources/SuiteUI/Gallery/GalleryTimeline.swift")
        let source = try String(contentsOf: file, encoding: .utf8)
        let start = try #require(source.range(of: "private func timecodeReadout("), "the readout moved; point this test at it")
        let end = try #require(source.range(of: "private func logView(", range: start.upperBound..<source.endIndex))
        let body = source[start.upperBound..<end.lowerBound]
        #expect(body.contains("unit: .timecode"))
        #expect(body.contains("Text(verbatim: timecode)\n                .font(SuiteFont.timecode)\n                .foregroundStyle(SuiteColor.textPrimary)"))
        #expect(body.contains("Text(\"Timecode\")"), "nothing labels the readout as timecode")
        #expect(body.contains(".help(TimelineTime.readoutHelp(rate: rate))"))
        #expect(body.contains(".accessibilityLabel(Text(verbatim: TimelineTime.readoutHelp(rate: rate)))"))
        #expect(!body.contains("SuiteColor.secondaryText") && !body.contains("monospacedDigit"))
    }
}
