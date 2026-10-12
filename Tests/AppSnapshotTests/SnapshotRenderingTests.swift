// SnapshotRenderingTests.swift: the snapshot helper draws real AppKit
// controls. A Slider rendered through it must not come out as ImageRenderer's
// placeholder, a yellow block with a "prohibited" sign. macOS only.
import AppKit
import SwiftUI
import Testing

@MainActor
@Test func snapshotsDrawRealSlidersNotPlaceholders() throws {
    let slider = Slider(value: .constant(0.4)).frame(width: 600).padding()
    let image = try #require(render(slider, scheme: .light))
    var yellow = 0
    for y in stride(from: 0, to: image.pixelsHigh, by: 4) {
        for x in stride(from: 0, to: image.pixelsWide, by: 4) {
            guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            if color.redComponent > 0.9, color.greenComponent > 0.7, color.greenComponent < 0.9, color.blueComponent < 0.2 {
                yellow += 1
            }
        }
    }
    #expect(yellow < 50, "the slider rendered as a placeholder (\(yellow) yellow samples)")
}
