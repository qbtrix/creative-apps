// DesignFrameLabels.swift: each visible frame's name, drawn in the canvas overlay
// over the artwork, at the place DesignFrameLabel decides: above the frame's
// top-left corner, or just inside it when the artboard has no room above. One
// Canvas laid out on the artboard (its top is 0 here) and clipped to it, as the
// artwork is, so the names land on the same pixels they did inside DesignArtwork.
// Names stay one size on screen at any zoom. A slot: the text styles (style-rows
// SR-t) change it here without touching DesignCanvasMarks.swift. Takes no clicks.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignFrameLabels: View {
    let painted: [DesignPainted]
    let zoom: Double

    var body: some View {
        let frames = painted.filter { $0.node.kind == .frame }
        let scale = usable(zoom)
        Canvas { context, _ in
            let fit = CGAffineTransform(scaleX: scale, y: scale)
            for item in frames { drawName(of: item, in: context, scaledBy: fit) }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension DesignColor {
    /// Whether dark ink reads on this color (Rec. 601 luma above the midpoint).
    var isLight: Bool { 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue) > 127.5 }
}

/// The color of a frame's name over `backdrop`: ink on a light fill, paper on a dark one, and
/// the secondary label color on the bare page, where the checkerboard sits behind it.
private func labelColor(over backdrop: DesignColor?) -> Color {
    guard let backdrop else { return SuiteColor.secondaryText }
    return backdrop.isLight ? SuiteColor.overlayInk.opacity(0.55) : SuiteColor.overlayPaper.opacity(0.7)
}

/// Draws a frame's name above its top-left corner, or just inside it when the artboard has no room
/// for the name above the frame (DesignFrameLabel decides). The name's own measured height sets the
/// room it needs.
private func drawName(of item: DesignPainted, in context: GraphicsContext, scaledBy fit: CGAffineTransform) {
    let box = item.node.frame.cgRect.applying(fit)
    let text = Text(item.node.name).font(SuiteFont.caption)
    let height = context.resolve(text).measure(in: CGSize(width: CGFloat.infinity, height: .infinity)).height
    let label = DesignFrameLabel.place(
        frameTop: Double(box.minY), artboardTop: 0, labelHeight: Double(height),
        gap: Double(SuiteSpacing.xxs), inset: Double(SuiteSpacing.xs))
    let color = labelColor(over: label.isInside ? item.node.fill : item.backdrop)
    let name = context.resolve(text.foregroundStyle(color))
    switch label {
    case .inside(let top):
        context.draw(name, at: CGPoint(x: box.minX + SuiteSpacing.xs, y: top), anchor: .topLeading)
    case .above(let bottom):
        context.draw(name, at: CGPoint(x: box.minX, y: bottom), anchor: .bottomLeading)
    }
}
