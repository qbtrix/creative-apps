// PhotoLevelsPrecisionTests.swift: Levels Black and White snap to levelsStep,
// so the inspector's fields, at levelsDecimals places, never show two distinct
// points as the same text, and a shown value typed back in gives the stored
// point itself. The fields round a value to `decimals` places and parse the
// text back as a Double; `shown` and `typedBack` do the same here, since
// SuiteUI's NumericInput doesn't build on Linux. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoLevelsPrecisionTests {
    private let step = AdjustmentSettings.levelsStep

    /// The whole number of places-units a field at levelsDecimals shows.
    private func shown(_ value: Float) -> Int64 {
        var scale = 1.0
        for _ in 0..<AdjustmentSettings.levelsDecimals { scale *= 10 }
        return Int64((Double(value) * scale).rounded())
    }

    /// The point the field's text gives back as an edit.
    private func typedBack(_ value: Float) -> Float {
        Float(Double(shown(value)) * step)
    }

    @Test func decimalsShowEveryStep() {
        var scale = 1.0
        for _ in 0..<AdjustmentSettings.levelsDecimals { scale *= 10 }
        #expect((step * scale).rounded() == 1)
    }

    @Test(arguments: [Float(0), 0.0004, 0.0005, 0.0015, 0.4995, 0.5, 0.9985, 0.9995, 0.9996, 1, Float(1).nextDown])
    func storedPointsRoundTripThroughTheirText(_ input: Float) {
        var settings = AdjustmentSettings()
        settings.apply(.whitePoint(input))
        if input > 0.0005 {
            #expect(typedBack(settings.whitePoint) == settings.whitePoint)
            settings.apply(.whitePoint(typedBack(settings.whitePoint)))
            #expect(settings.whitePoint == typedBack(settings.whitePoint))
        }
        settings.apply(.whitePoint(1))
        settings.apply(.blackPoint(input))
        #expect(typedBack(settings.blackPoint) == settings.blackPoint)
    }

    @Test func blackAndWhiteAtTheTopNeverReadTheSame() {
        var settings = AdjustmentSettings()
        // 0.9996 snaps to 1, at white: refused, so black stays apart.
        settings.apply(.blackPoint(0.9996))
        #expect(settings.blackPoint == 0)
        settings.apply(.blackPoint(0.9994))
        #expect(settings.blackPoint == Float(1 - step))
        #expect(shown(settings.blackPoint) != shown(settings.whitePoint))
    }

    @Test func blackAndWhiteAtTheBottomNeverReadTheSame() {
        var settings = AdjustmentSettings()
        settings.apply(.whitePoint(0.0004))
        #expect(settings.whitePoint == 1)
        settings.apply(.whitePoint(0.0006))
        #expect(settings.whitePoint == Float(step))
        #expect(shown(settings.blackPoint) != shown(settings.whitePoint))
    }

    @Test func distinctPointsAlwaysShowDistinctText() {
        var settings = AdjustmentSettings()
        for index in 0...4000 {
            let value = Float(index) / 4000
            settings.apply(index.isMultiple(of: 2) ? .blackPoint(value) : .whitePoint(1 - value))
            #expect(settings.blackPoint < settings.whitePoint)
            #expect(shown(settings.blackPoint) < shown(settings.whitePoint))
            #expect(typedBack(settings.blackPoint) == settings.blackPoint)
            #expect(typedBack(settings.whitePoint) == settings.whitePoint)
        }
    }
}
