// NewDocumentSheetTests.swift (document-setup DS-5): the New Document sheet's rules, on NewDocumentForm: a preset
// fills every field, a unit change keeps the pixels, the clipboard choice shows only with a size, settings mode
// shows the anchor grid instead of presets, rate and duration show only for timed apps, and every control names
// the parameter it sets.
import SuiteKernel
import SuiteModel
import Testing

@testable import SuiteUI

@Suite struct NewDocumentSheetTests {
    static let timed = DocumentLimits(rates: FrameRate.common, maxSeconds: 600)
    static let story = NewDocumentPreset(id: "flare.story", app: .flare, title: "Story", detail: "1080 × 1920, 30 fps", parameters: [
        "width": "1080", "height": "1920", "unit": "px", "resolution": "144", "background": "transparent", "fps": "30", "duration": "12",
    ])
    static let start = DocumentSetup(width: 1920, height: 1080, frameRate: FrameRate(whole: 24), durationSeconds: 5)

    @Test func presetFillsEveryField() {
        var form = NewDocumentForm(Self.start, limits: Self.timed)
        form.pick(Self.story)
        #expect(form.setup == DocumentSetup(width: 1080, height: 1920, unit: .px, resolution: 144, background: .transparent,
                                            frameRate: FrameRate(whole: 30), durationSeconds: 12))
        #expect(form.chosen == "flare.story")
        #expect(form.text(.width) == "1080" && form.text(.height) == "1920" && form.text(.resolution) == "144")
        #expect(form.text(.duration) == "12")
    }

    @Test func unitChangeKeepsPixels() {
        var form = NewDocumentForm(DocumentSetup(width: 1800, height: 1200, resolution: 300), limits: DocumentLimits())
        let pixels = form.setup.pixelSize
        form.setUnit(.inch)
        #expect(form.setup.unit == .inch)
        #expect(form.setup.pixelSize.width == pixels.width && form.setup.pixelSize.height == pixels.height)
        #expect(form.text(.width) == NewDocumentForm.text(form.setup.width))
        #expect(form.chosen == nil)
    }

    @Test func typingSetsTheValueAndKeepsTheText() {
        var form = NewDocumentForm(Self.start, limits: Self.timed)
        form.type("4", into: .width)
        #expect(form.setup.width == 4 && form.text(.width) == "4")
        form.type("4.", into: .width)
        #expect(form.setup.width == 4 && form.text(.width) == "4.")
        form.type("", into: .height)
        #expect(form.setup.height == 0 && form.text(.height) == "")
    }

    @Test func clipboardShowsOnlyWithASize() {
        let presets = [Self.story]
        #expect(NewDocumentForm.choices(.new(presets: presets, clipboard: nil)).map(\.id) == ["flare.story"])
        let withSize = NewDocumentForm.choices(.new(presets: presets, clipboard: (width: 1200, height: 800)))
        #expect(withSize.map(\.id) == [NewDocumentForm.clipboardID, "flare.story"])
        #expect(withSize.first?.parameters["width"] == "1200" && withSize.first?.parameters["height"] == "800")
        #expect(NewDocumentForm.choices(.settings).isEmpty)
    }

    @Test func settingsShowAnchorsAndHidePresets() {
        let new = NewDocumentForm.sections(.new(presets: [Self.story], clipboard: nil), limits: DocumentLimits())
        let settings = NewDocumentForm.sections(.settings, limits: DocumentLimits())
        #expect(new.contains(.presets) && !new.contains(.anchor))
        #expect(settings.contains(.anchor) && !settings.contains(.presets))
    }

    @Test func rateAndDurationOnlyForTimedApps() {
        #expect(NewDocumentForm.sections(.settings, limits: Self.timed).contains(.timing))
        #expect(!NewDocumentForm.sections(.settings, limits: DocumentLimits()).contains(.timing))
    }

    @Test func everyControlNamesItsParameter() {
        #expect(NewDocumentForm.parameter("width", .new(presets: [], clipboard: nil)) == "file.new width")
        #expect(NewDocumentForm.parameter("anchor", .settings) == "document.set-settings anchor")
    }

    @Test func createWaitsForNoProblems() {
        let form = NewDocumentForm(Self.start, limits: Self.timed)
        #expect(form.canCreate == form.setup.problems(Self.timed).isEmpty)
        #expect(form.problem(.width) == form.setup.problems(Self.timed).first { $0.field == .width }?.text)
    }
}
