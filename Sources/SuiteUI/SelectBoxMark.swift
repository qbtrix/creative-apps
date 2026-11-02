// SelectBoxMark.swift: the one box a Select or marquee drag shows over a canvas (#6012): `rect` in document units
// at `zoom`, a 1 pt accent edge on a paper halo (as every canvas mark has, so it shows over a blue sky) over a
// 10 % accent fill. A shape, not a Canvas, so a box dragged past the document's edge still shows. It takes no
// clicks and is hidden from accessibility. Photo's Select and Design's
// marquee draw it; the box itself comes from SuiteKernel's `Marquee.rect`.
import SwiftUI

public struct SelectBoxMark: View {
    let rect: CGRect
    let zoom: Double

    public init(rect: CGRect, zoom: Double) {
        (self.rect, self.zoom) = (rect, zoom)
    }

    public var body: some View {
        let scale = zoom.isFinite && zoom > 0 ? zoom : 1
        let box = Path(rect.applying(CGAffineTransform(scaleX: scale, y: scale)))
        ZStack(alignment: .topLeading) {
            box.fill(SuiteColor.accent.opacity(0.1))
            box.stroke(SuiteColor.overlayPaper, lineWidth: SuiteSize.pointMarkPaper)
            box.stroke(SuiteColor.accent, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
