// PhotoCanvasSizeSheetTests.swift: Image > Canvas Size… (transform PT-3). The
// sheet's relative field adds to the image's size (+400 on 2000 x 1400 is
// 2400 x 1800), its 3 x 3 anchor grid emits the BoxAnchor clicked, and a
// smaller size shows "The canvas will be cropped.". Snapshots the sheet over
// the Photo window, growing and cropping, Light and Dark: writes
// photo-canvas-size-light.png, photo-canvas-size-dark.png,
// photo-canvas-size-crop-light.png and photo-canvas-size-crop-dark.png.
// macOS only.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoCanvasSizeSheetTests {
    private let photo = CanvasSize(width: 2000, height: 1400)

    /// The draft the sheet last sent, kept in a box the closure can write.
    private final class Sent { var draft: CanvasSizeDraft? }

    @Test func relativePlus400Gives2400By1800() throws {
        let sent = Sent()
        let relative = CanvasSizeDraft(old: photo).with(relative: true)
        CanvasSizeSheet(draft: relative, onDraft: { sent.draft = $0 }).typeWidth("400")
        let wider = try #require(sent.draft)
        CanvasSizeSheet(draft: wider, onDraft: { sent.draft = $0 }).typeHeight("400")
        let grown = try #require(sent.draft)
        #expect(grown.newSize == CanvasSize(width: 2400, height: 1800))
        #expect(CanvasSizeSheet(draft: grown).cropNote == nil)
    }

    @Test func theRelativeCheckboxKeepsTheSize() {
        let sent = Sent()
        CanvasSizeSheet(draft: CanvasSizeDraft(old: photo), onDraft: { sent.draft = $0 }).setRelative(true)
        #expect(sent.draft?.relative == true)
        #expect(sent.draft?.newSize == photo)
    }

    @Test func theAnchorGridEmitsItsAnchor() {
        let options = CanvasSizeSheet.anchorOptions
        #expect(options.map(\.id) == BoxAnchor.allCases)
        #expect(options.first?.identifier == "photo.canvas-size.anchor.topLeft")
        let sent = Sent()
        let sheet = CanvasSizeSheet(draft: CanvasSizeDraft(old: photo), onDraft: { sent.draft = $0 })
        for anchor in [BoxAnchor.topLeft, .bottomRight, .top] {
            sheet.chooseAnchor(anchor)
            #expect(sent.draft?.anchor == anchor)
        }
    }

    @Test func aSmallerSizeShowsTheCropNote() {
        let smaller = CanvasSizeDraft(old: photo).with(width: 1600)
        #expect(CanvasSizeSheet(draft: smaller).cropNote == "The canvas will be cropped.")
        #expect(CanvasSizeSheet(draft: CanvasSizeDraft(old: photo).with(width: 2400)).cropNote == nil)
    }

    @Test func okSendsTheDraft() {
        let sent = Sent()
        let grown = CanvasSizeDraft(old: photo).with(width: 2400)
        CanvasSizeSheet(draft: grown, onResize: { sent.draft = $0 }).resize()
        #expect(sent.draft == grown)
        let unchanged = Sent()
        CanvasSizeSheet(draft: CanvasSizeDraft(old: photo), onResize: { unchanged.draft = $0 }).resize()
        #expect(unchanged.draft == nil)
    }

    @Test func sheetOverTheWindow() throws {
        var model = PhotoWorkspace()
        let (w, h) = (640, 480)
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                bytes[(y * w + x) * 4] = UInt8(x * 255 / w)
                bytes[(y * w + x) * 4 + 1] = UInt8(y * 255 / h)
                bytes[(y * w + x) * 4 + 2] = 160
            }
        }
        try model.open(rgba8: bytes, width: w, height: h, name: "gradient.png")
        let tiles = try photoTiles(model)
        let size = CanvasSize(width: w, height: h)
        let grow = CanvasSizeDraft(old: size, relative: true).with(width: 400).with(height: 400).with(anchor: .topLeft)
        let crop = CanvasSizeDraft(old: size).with(width: 480).with(height: 480)
        for (draft, suffix) in [(grow, ""), (crop, "-crop")] {
            for scheme in [ColorScheme.light, .dark] {
                let view = ZStack(alignment: .top) {
                    PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1)
                    CanvasSizeSheet(draft: draft)
                        .background(SuiteColor.panel, in: .rect(cornerRadius: SuiteRadius.large))
                        .padding(.top, SuiteSpacing.xxl)
                }
                let name = "photo-canvas-size\(suffix)-\(scheme == .dark ? "dark" : "light")"
                try snapshot(view, name: name, scheme: scheme)
            }
        }
    }
}
