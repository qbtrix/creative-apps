// PhotoLevelsFormatTests.swift: Levels Black and White read as a percent of
// the tonal range (#1631): black 0 is "0%", white 1 is "100%", the fields
// scrub over 0...100, every levelsStep point shows apart, and a shown percent
// typed back gives the stored point itself. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoLevelsFormatTests {
    @Test func endsReadAsPercent() {
        let defaults = AdjustmentSettings()
        #expect(PhotoLevelsFormat.text(defaults.blackPoint) == "0%")
        #expect(PhotoLevelsFormat.text(defaults.whitePoint) == "100%")
        #expect(PhotoLevelsFormat.text(0.5) == "50%")
        #expect(PhotoLevelsFormat.text(0.123) == "12.3%")
        #expect(PhotoLevelsFormat.unit == "%")
        #expect(PhotoLevelsFormat.range == 0...100)
    }

    /// Every point on the levelsStep grid shows its own text, and that text,
    /// typed back as a percent, stores the same point.
    @Test func everyStepShowsApartAndTypesBack() {
        var seen = Set<String>()
        for k in 1...1000 {
            var settings = AdjustmentSettings()
            settings.apply(.whitePoint(Float(Double(k) * AdjustmentSettings.levelsStep)))
            let stored = settings.whitePoint
            let text = PhotoLevelsFormat.text(stored)
            #expect(seen.insert(text).inserted, "\(text) shows twice")
            let typed = Double(text.dropLast()) ?? .nan
            var again = settings
            again.apply(.whitePoint(PhotoLevelsFormat.point(percent: typed)))
            #expect(again.whitePoint == stored, "\(text) typed back moved white")
        }
        #expect(seen.count == 1000)
    }

    @Test func percentRoundTripsThroughPoint() {
        #expect(PhotoLevelsFormat.percent(1) == 100)
        #expect(PhotoLevelsFormat.point(percent: 25) == 0.25)
        #expect(PhotoLevelsFormat.decimals == 1)
    }
}
