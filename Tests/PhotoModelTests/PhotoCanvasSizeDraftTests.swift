// PhotoCanvasSizeDraftTests.swift: the Canvas Size sheet's maths (transform
// PT-3): relative sizes add to the image's size, switching between relative and
// absolute keeps the size, fields clamp to 1...maxSide, a smaller side brings
// the crop note, an unchanged size disables OK with a reason, and the anchor
// grid's titles follow BoxAnchor. Runs on Linux and macOS.
import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoCanvasSizeDraftTests {
    private let photo = CanvasSize(width: 2000, height: 1400)

    @Test func relativeAddsToTheImageSize() {
        let draft = CanvasSizeDraft(old: photo).with(relative: true).with(width: 400).with(height: 400)
        #expect(draft.relative)
        #expect(draft.newSize == CanvasSize(width: 2400, height: 1800))
        #expect(draft.cropNote == nil)
        #expect(draft.help == nil)
    }

    @Test func absoluteStartsAtTheImageSizeAndRelativeAtZero() {
        let absolute = CanvasSizeDraft(old: photo)
        #expect(!absolute.relative)
        #expect(absolute.width == 2000 && absolute.height == 1400)
        #expect(absolute.anchor == .center)
        let relative = absolute.with(relative: true)
        #expect(relative.width == 0 && relative.height == 0)
        #expect(relative.newSize == photo)
    }

    @Test func switchingModesKeepsTheSize() {
        let absolute = CanvasSizeDraft(old: photo).with(width: 2600).with(height: 1000)
        let relative = absolute.with(relative: true)
        #expect(relative.width == 600 && relative.height == -400)
        #expect(relative.newSize == CanvasSize(width: 2600, height: 1000))
        let back = relative.with(relative: false)
        #expect(back.width == 2600 && back.height == 1000)
        #expect(back.with(relative: false) == back)
    }

    @Test func fieldsClampSoEachSideStaysInRange() {
        let absolute = CanvasSizeDraft(old: photo).with(width: 0).with(height: 99_999)
        #expect(absolute.newSize == CanvasSize(width: 1, height: PhotoWorkspace.maxSide))
        let relative = CanvasSizeDraft(old: photo, relative: true).with(width: -5000).with(height: 20_000)
        #expect(relative.newSize == CanvasSize(width: 1, height: PhotoWorkspace.maxSide))
        #expect(relative.widthRange == -1999...(PhotoWorkspace.maxSide - 2000))
        #expect(absolute.heightRange == 1...PhotoWorkspace.maxSide)
    }

    @Test func aSmallerSideBringsTheCropNote() {
        let narrower = CanvasSizeDraft(old: photo).with(width: 1999)
        #expect(narrower.crops)
        #expect(narrower.cropNote == "The canvas will be cropped.")
        let shorter = CanvasSizeDraft(old: photo, relative: true).with(width: 500).with(height: -1)
        #expect(shorter.crops)
        let bigger = CanvasSizeDraft(old: photo).with(width: 2001).with(height: 1400)
        #expect(!bigger.crops && bigger.cropNote == nil)
    }

    @Test func anUnchangedSizeDisablesOK() {
        #expect(CanvasSizeDraft(old: photo).help == "Choose a size different from the image's.")
        #expect(CanvasSizeDraft(old: photo).with(height: 1401).help == nil)
    }

    @Test func theAnchorIsKeptAndTitled() {
        let draft = CanvasSizeDraft(old: photo).with(anchor: .topLeft).with(relative: true).with(width: 10)
        #expect(draft.anchor == .topLeft)
        #expect(CanvasSizeDraft.anchorTitle(.topLeft) == "Top Left")
        #expect(CanvasSizeDraft.anchorTitle(.center) == "Center")
        #expect(CanvasSizeDraft.anchorTitle(.bottom) == "Bottom")
        #expect(Set(BoxAnchor.allCases.map(CanvasSizeDraft.anchorTitle)).count == 9)
    }
}
