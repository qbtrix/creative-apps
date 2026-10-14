// PhotoStraightenSnapshots.swift: Image > Straighten while its sheet is open:
// the Photo window previewing a 7.5 degree turn with Crop to Fit (the picture
// turned, the grid and the crop shade over it) and the sheet drawn on top, the
// way a sheet sits over the window. Light and Dark. Writes
// photo-straighten-light.png and photo-straighten-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoStraightenSnapshots {
    @Test func sheetOverAPreviewedTurn() throws {
        var model = PhotoWorkspace()
        let (w, h) = (640, 480)
        // Sky over sea, the horizon rising 7.5 degrees to the right, so the preview levels it.
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let sky = y < 280 - x * 84 / w
                bytes[(y * w + x) * 4] = sky ? 120 : 20
                bytes[(y * w + x) * 4 + 1] = sky ? 170 : 70
                bytes[(y * w + x) * 4 + 2] = sky ? 230 : 120
            }
        }
        try model.open(rgba8: bytes, width: w, height: h, name: "horizon.png")
        let draft = StraightenDraft(degrees: 7.5, cropToFit: true)
        let frame = try #require(model.straightenFrame(degrees: draft.degrees, cropToFit: draft.cropToFit))
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            let view = ZStack(alignment: .top) {
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1, straighten: draft)
                StraightenSheet(draft: draft, frame: frame)
                    .background(SuiteColor.panel, in: .rect(cornerRadius: SuiteRadius.large))
                    .padding(.top, SuiteSpacing.xxl)
            }
            try snapshot(view, name: "photo-straighten-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
