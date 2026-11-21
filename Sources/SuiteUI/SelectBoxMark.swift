// SelectBoxMark.swift: the one box a Select or marquee drag shows over a canvas (#6012): `rect` in document units
// at `zoom`, a 1 pt accent edge on a paper halo (as every canvas mark has, so it shows over a blue sky) over a
// 10 % accent fill. A shape, not a Canvas, so a box dragged past the document's edge still shows. It takes no
// clicks and is hidden from accessibility. Photo's Select and Design's
// marquee draw it; the box itself comes from SuiteKernel's `Marquee.rect`. Its sibling GroupScopeMark is the
// entered group's box (SuiteKernel's GroupScope, area-selection AR-14): the same accent edge on its halo, dimmed
// to half and unfilled, so the scope a click picks in shows around the picked child without reading as a selection.
import SwiftUI

public struct SelectBoxMark: View {
    let rect: CGRect
    let zoom: Double
    var filled = true

    public init(rect: CGRect, zoom: Double) {
        (self.rect, self.zoom) = (rect, zoom)
    }

    init(rect: CGRect, zoom: Double, filled: Bool) {
        (self.rect, self.zoom, self.filled) = (rect, zoom, filled)
    }

    public var body: some View {
        let scale = zoom.isFinite && zoom > 0 ? zoom : 1
        let box = Path(rect.applying(CGAffineTransform(scaleX: scale, y: scale)))
        ZStack(alignment: .topLeading) {
            box.fill(SuiteColor.accent.opacity(filled ? 0.1 : 0))
            box.stroke(SuiteColor.overlayPaper, lineWidth: SuiteSize.pointMarkPaper)
            box.stroke(SuiteColor.accent, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The group a click is inside: `rect` in document units at `zoom`, the select box's accent edge on its paper halo
/// at half strength, with no fill. It takes no clicks and is hidden from accessibility.
public struct GroupScopeMark: View {
    let rect: CGRect
    let zoom: Double

    public init(rect: CGRect, zoom: Double) {
        (self.rect, self.zoom) = (rect, zoom)
    }

    public var body: some View {
        SelectBoxMark(rect: rect, zoom: zoom, filled: false).opacity(0.5)
    }
}
