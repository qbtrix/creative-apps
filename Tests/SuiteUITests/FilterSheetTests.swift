// FilterSheetTests.swift (adjust-everywhere AJ-3): drafts take the kind's ranges
// and starts, clamp and snap; OK emits one intent, Cancel nothing; FilterMenu's
// items are catalog commands, off on the stub with the AJ-5 reason, and so is the
// sheet's OK. macOS only.
import SuiteImaging
import SuiteKernel
import Testing

@testable import SuiteUI

@Suite struct FilterSheetTests {
    @Test(arguments: ImagingFilter.ids) func startsAtTheFilterDefaults(_ id: String) throws {
        let draft = try #require(FilterSheetDraft(id), "no sheet for \(id)")
        #expect(draft.result(.ok) == .filter(try #require(ImagingFilter.defaults(id))))
        #expect(draft.preview, "Preview starts on")
        for slider in draft.sliders {
            var high = draft, low = draft
            high.set(slider.id, to: slider.range.upperBound + 1000)
            low.set(slider.id, to: slider.range.lowerBound - 1000)
            #expect(high.value(slider.id) == slider.range.upperBound, "\(id).\(slider.id) ignores its top")
            #expect(low.value(slider.id) == slider.range.lowerBound, "\(id).\(slider.id) ignores its bottom")
        }
    }

    @Test func rangesAndStepsComeFromTheKind() throws {
        func ranges(_ id: String) -> [ClosedRange<Double>]? { FilterSheetDraft(id)?.sliders.map(\.range) }
        #expect(ranges("gaussian-blur") == [ImagingFilter.blurRadius])
        #expect(ranges("motion-blur") == [ImagingFilter.motionDegrees, ImagingFilter.motionDistance])
        #expect(ranges("sharpen") == [ImagingFilter.sharpenAmount, ImagingFilter.sharpenRadius, ImagingFilter.sharpenThreshold])
        #expect(ranges("reduce-noise") == [ImagingFilter.percent, ImagingFilter.percent])
        #expect(ranges("add-noise") == [ImagingFilter.percent])
        #expect(ranges("black-and-white") == Array(repeating: GrayWeights.range, count: 6))
        #expect(FilterSheetDraft("gaussian-blur")?.sliders.map(\.step) == [0.1])
        #expect(FilterSheetDraft("sharpen")?.sliders.map(\.step) == [1, 0.1, 1])
        #expect(FilterSheetDraft("invert") == nil, "Invert has nothing to set")
        #expect(FilterSheetDraft("swirl") == nil)
    }

    @Test func okEmitsOneIntentWithTheValues() throws {
        var blur = try #require(FilterSheetDraft("gaussian-blur"))
        blur.set("radius", to: 8.04)
        blur.setPreview(false)
        #expect(blur.result(.ok) == .filter(.gaussianBlur(radius: 8)), "the radius snaps to its 0.1 step")
        var motion = try #require(FilterSheetDraft("motion-blur"))
        motion.set("degrees", to: 45)
        motion.set("distance", to: 30)
        #expect(motion.result(.ok) == .filter(.motionBlur(degrees: 45, distance: 30)))
        var noise = try #require(FilterSheetDraft("add-noise"))
        noise.set("amount", to: 20)
        noise.setMonochrome(true)
        #expect(noise.result(.ok) == .filter(.addNoise(amount: 20, monochrome: true, seed: 0)))
        var bw = try #require(FilterSheetDraft("black-and-white"))
        #expect(bw.result(.ok) == .kind(.blackAndWhite(.neutral)))
        bw.set("red", to: 100)
        var weights = GrayWeights.neutral
        weights.red = 100
        #expect(bw.result(.ok) == .kind(.blackAndWhite(weights)))
        #expect(bw.command == "adjust.black-and-white" && blur.command == "filter.gaussian-blur")
    }

    @Test func cancelEmitsNothing() throws {
        var blur = try #require(FilterSheetDraft("gaussian-blur"))
        blur.set("radius", to: 8)
        #expect(blur.result(.cancel) == nil)
    }

    @Test func menuItemsAreCatalogCommands() {
        let specs = AdjustCommands.specs(PendingAdjustTarget.self)
        let filters = FilterMenu.filter.flatMap(\.items)
        #expect(filters.map(\.command) == ImagingFilter.ids.map { "filter.\($0)" })
        #expect(FilterMenu.filter.map(\.title) == ["Blur", nil, "Noise"])
        #expect(FilterMenu.adjustments.map(\.command) == ["adjust.black-and-white", "adjust.invert"])
        #expect(FilterMenu.adjustments.map(\.title) == ["Black & White…", "Invert"])
        for item in filters {
            #expect(item.title == ImagingFilter.defaults(item.sheet ?? "").map { "\($0.title)…" }, "\(item.command)")
        }
        let stub = PendingAdjustTarget()
        for item in FilterMenu.all {
            let spec = specs.first { $0.id == item.command }
            #expect(spec != nil, "\(item.command) has no command")
            #expect(spec?.availability(stub).why == "Filters arrive with AJ-5.", "\(item.command) isn't off with its reason")
            #expect(item.sheet.map { FilterSheetDraft($0) != nil } ?? true, "\(item.command) opens no sheet")
        }
    }

    /// SuiteSheet's default action is the draft's catalog command (#5789): off on the stub, with its reason as help.
    @MainActor @Test func okIsTheCommandOnTheTarget() throws {
        let sheet = FilterSheet(draft: try #require(FilterSheetDraft("gaussian-blur")), target: PendingAdjustTarget())
        #expect(sheet.ok.title == "OK")
        #expect(!sheet.ok.isEnabled, "OK runs on a target that has no filters")
        #expect(sheet.ok.help == "OK: Filters arrive with AJ-5.")
    }
}
