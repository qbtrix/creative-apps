// FrameRateMenuTests.swift: FR-u (frame-rates packet, FR-5 and FR-6). The
// shared FrameRateMenu lists SuiteKernel's FrameRate.common in order, each
// titled as the time.rates commands title it ("29.97 fps"), with the bound
// rate checked; the timeline readout shows timecode at the document's rate
// through SuiteKernel's Timecode (";" before the frames at a drop-frame rate).
import SuiteKernel
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
}
