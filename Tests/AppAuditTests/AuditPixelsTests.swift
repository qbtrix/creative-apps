// AuditPixelsTests.swift: the app audit's pixel math on synthetic images:
// WCAG luminance and contrast against published values, and the ink of a
// frame for solid, grey, antialiased, dimmed, blank and out-of-range crops.
// Runs on Linux and macOS (docs/blueprints/app-audit.md).
import Testing

/// A `width` x `height` image of `background` with `paint` applied to each
/// pixel (x, y) it returns a gray value for.
private func image(
    _ width: Int, _ height: Int, background: UInt8, paint: (Int, Int) -> UInt8? = { _, _ in nil }
) -> AppAudit.Image {
    var rgba = [UInt8]()
    for y in 0..<height {
        for x in 0..<width {
            let v = paint(x, y) ?? background
            rgba += [v, v, v, 255]
        }
    }
    return AppAudit.Image(width: width, height: height, rgba: rgba)
}

private func whole(_ image: AppAudit.Image) -> AppAudit.Rect {
    AppAudit.Rect(x: 0, y: 0, width: Double(image.width), height: Double(image.height))
}

@Test func luminanceMatchesWCAG() {
    #expect(AppAudit.luminance(255, 255, 255) == 1)
    #expect(AppAudit.luminance(0, 0, 0) == 0)
    #expect(abs(AppAudit.luminance(0x77, 0x77, 0x77) - 0.1845) < 0.0005)
    #expect(abs(AppAudit.luminance(255, 0, 0) - 0.2126) < 0.0001)
}

@Test func contrastMatchesWCAG() {
    #expect(AppAudit.contrast(0, 1) == 21)
    #expect(AppAudit.contrast(0.5, 0.5) == 1)
    // #767676 is the lightest grey that passes 4.5:1 on white.
    let grey = AppAudit.luminance(0x76, 0x76, 0x76)
    #expect(abs(AppAudit.contrast(1, grey) - 4.54) < 0.01)
    #expect(AppAudit.contrast(1, AppAudit.luminance(0x77, 0x77, 0x77)) < 4.5)
}

@Test func blackStrokeOnWhiteIsFullInk() throws {
    let shot = image(20, 10, background: 255) { x, y in (4...6).contains(x) && (2...7).contains(y) ? 0 : nil }
    let ink = try #require(AppAudit.ink(of: shot, in: whole(shot)))
    #expect(ink.background == 1)
    #expect(ink.contrast == 21)
}

@Test func greyTextOnWhiteReadsItsContrast() throws {
    let shot = image(20, 10, background: 255) { x, y in x.isMultiple(of: 3) && y > 1 ? 0x76 : nil }
    let ink = try #require(AppAudit.ink(of: shot, in: whole(shot)))
    #expect(abs(ink.contrast - 4.54) < 0.01)
}

@Test func whiteTextOnDarkPanel() throws {
    let shot = image(20, 10, background: 0x1E) { x, y in x.isMultiple(of: 4) && y > 2 ? 255 : nil }
    let ink = try #require(AppAudit.ink(of: shot, in: whole(shot)))
    #expect(abs(ink.contrast - 16.67) < 0.05)
}

@Test func antialiasedEdgesDontHideTheCore() throws {
    // 10 black core pixels and 20 mid-grey edge pixels: the core sets the ink.
    let shot = image(40, 10, background: 255) { x, y in
        guard y == 4 else { return nil }
        return x < 10 ? 0 : x < 30 ? 0x80 : nil
    }
    let ink = try #require(AppAudit.ink(of: shot, in: whole(shot)))
    #expect(ink.contrast == 21)
}

@Test func dimmedStrokeHasLessInk() throws {
    // The same stroke at full grey and at about 40% opacity over white.
    func stroke(_ v: UInt8) -> AppAudit.Image {
        image(20, 10, background: 255) { x, y in (8...10).contains(x) && y > 1 ? v : nil }
    }
    let full = try #require(AppAudit.ink(of: stroke(0x55), in: whole(stroke(0x55))))
    let dim = try #require(AppAudit.ink(of: stroke(0xBB), in: whole(stroke(0xBB))))
    #expect(full.contrast > 7)
    #expect(dim.contrast < 2)
}

@Test func blankFrameHasNoInk() throws {
    let shot = image(10, 10, background: 0x80) { x, y in x == 0 && y == 0 ? 0x70 : nil }
    #expect(try #require(AppAudit.ink(of: shot, in: whole(shot))).contrast == 1)
}

@Test func cropIsCutToTheImageAndRoundedInward() throws {
    // Black covers columns 0-1; a crop from x 1.5 starts at column 2, so no ink.
    let shot = image(10, 10, background: 255) { x, _ in x < 2 ? 0 : nil }
    let inside = AppAudit.Rect(x: 1.5, y: -5, width: 20, height: 20)
    #expect(try #require(AppAudit.ink(of: shot, in: inside)).contrast == 1)
    #expect(AppAudit.ink(of: shot, in: AppAudit.Rect(x: 20, y: 0, width: 5, height: 5)) == nil)
    #expect(AppAudit.ink(of: shot, in: AppAudit.Rect(x: 0, y: 0, width: 3, height: 3)) == nil)
}

@Test func mismatchedBufferIsNotMeasured() {
    let broken = AppAudit.Image(width: 10, height: 10, rgba: [0, 0, 0, 255])
    #expect(AppAudit.ink(of: broken, in: AppAudit.Rect(x: 0, y: 0, width: 10, height: 10)) == nil)
}
