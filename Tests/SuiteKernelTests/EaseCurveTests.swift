// EaseCurveTests.swift (editor-kernel EK-14, slice EK-keys): checks first for
// `EasePreset`, the one preset list every easing menu offers, and `EaseCurve`,
// the one handle math for a curve editor: handles, moving a handle (x clamped)
// and samples along the curve at counts 1 and 5000. On since EK-15.
import Testing
import SuiteKernel

@Suite struct EaseCurveTests {
    // MARK: EasePreset

    @Test func presetsSetFlareCoreEasings() {
        #expect(EasePreset.linear.easing == .linear)
        #expect(EasePreset.ease.easing == Easing.ease)
        #expect(EasePreset.easeIn.easing == Easing.easeIn)
        #expect(EasePreset.easeOut.easing == Easing.easeOut)
        #expect(EasePreset.easeInOut.easing == Easing.easeInOut)
        #expect(EasePreset.hold.easing == .hold)
    }

    @Test func presetTitlesAreWordsNotRawValues() {
        let titles = EasePreset.allCases.map(\.title)
        #expect(Set(titles).count == EasePreset.allCases.count)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(EasePreset.easeInOut.title != EasePreset.easeInOut.rawValue)
    }

    // MARK: handles

    @Test func cubicHasTwoHandles() {
        #expect(EaseCurve.handles(of: .ease) == [Point(x: 0.25, y: 0.1), Point(x: 0.25, y: 1)])
        #expect(EaseCurve.handles(of: .cubicBezier(x1: 0.1, y1: -0.5, x2: 0.9, y2: 1.5))
            == [Point(x: 0.1, y: -0.5), Point(x: 0.9, y: 1.5)])
    }

    @Test func linearAndHoldHaveNoHandles() {
        #expect(EaseCurve.handles(of: .linear) == nil)
        #expect(EaseCurve.handles(of: .hold) == nil)
    }

    // MARK: moving

    @Test func movingHandleZero() {
        let moved = EaseCurve.moving(0, to: Point(x: 0.3, y: 0.8), in: .ease)
        #expect(moved == .cubicBezier(x1: 0.3, y1: 0.8, x2: 0.25, y2: 1))
    }

    @Test func movingHandleOne() {
        let moved = EaseCurve.moving(1, to: Point(x: 0.6, y: 0.2), in: .easeIn)
        #expect(moved == .cubicBezier(x1: 0.42, y1: 0, x2: 0.6, y2: 0.2))
    }

    @Test func movingClampsXButNotY() {
        let past = EaseCurve.moving(1, to: Point(x: 1.5, y: 1.4), in: .ease)
        #expect(past == .cubicBezier(x1: 0.25, y1: 0.1, x2: 1, y2: 1.4))
        let before = EaseCurve.moving(0, to: Point(x: -0.2, y: -0.3), in: .ease)
        #expect(before == .cubicBezier(x1: 0, y1: -0.3, x2: 0.25, y2: 1))
    }

    // MARK: samples

    @Test func oneSampleIsOnePoint() {
        let points = EaseCurve.samples(of: .ease, count: 1)
        #expect(points.count == 1)
        #expect(points.allSatisfy { $0.isFinite })
    }

    @Test func capAt4096() {
        #expect(EaseCurve.samples(of: .ease, count: 5000).count == 4096)
        #expect(EaseCurve.samples(of: .ease, count: 4096).count == 4096)
    }

    @Test func samplesRunFromOriginToOne() {
        let points = EaseCurve.samples(of: .easeInOut, count: 5000)
        #expect(points.first == Point(x: 0, y: 0))
        #expect(points.last == Point(x: 1, y: 1))
        #expect(zip(points, points.dropFirst()).allSatisfy { $0.x <= $1.x })
    }

    @Test func linearSamplesLieOnTheDiagonal() {
        let points = EaseCurve.samples(of: .linear, count: 11)
        #expect(points.count == 11)
        #expect(points.allSatisfy { abs($0.x - $0.y) < 1e-9 })
    }
}
