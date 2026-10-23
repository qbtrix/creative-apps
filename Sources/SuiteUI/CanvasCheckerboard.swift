// CanvasCheckerboard.swift: the checkerboard behind a canvas document, as one
// layer whose background colour is a pattern of the two checker tones.
// Core Animation tiles a pattern background when it composites, so the
// checkerboard costs nothing per frame and no memory beyond its 16 pt tile.
// A SwiftUI pattern fill the artboard's size was rasterized whole on the CPU
// into a wide-colour backing store (an 8K document at 100 %: about 1 GB and
// 350 ms), and again on every pan frame while that store fit the layer size
// limit, which is why panning lagged from 60 % to about 150 % zoom and was
// smooth above. The tones follow the environment's appearance; the view
// takes no pointer input, so the viewport's gestures see every click. macOS only.
import AppKit
import SwiftUI

/// The canvas checkerboard: SuiteColor's checker tones in `SuiteSize.checkerSquare` squares.
struct CanvasCheckerboard: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = PassThroughView()
        view.wantsLayer = true
        view.layer?.actions = ["backgroundColor": NSNull()]
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        let light = SuiteColor.checkerLight.resolve(in: context.environment).cgColor
        let dark = SuiteColor.checkerDark.resolve(in: context.environment).cgColor
        view.layer?.backgroundColor = Self.pattern(light: light, dark: dark)
    }

    /// Two squares of each tone, light at the top left, as one pattern colour; nil only if CoreGraphics
    /// refuses the pattern (the layer then shows no checkerboard).
    nonisolated static func pattern(light: CGColor, dark: CGColor) -> CGColor? {
        let square = SuiteSize.checkerSquare
        let tones = Unmanaged.passRetained(Tones(light: light, dark: dark, square: square))
        var callbacks = CGPatternCallbacks(
            version: 0,
            drawPattern: { info, context in
                guard let info else { return }
                let tones = Unmanaged<Tones>.fromOpaque(info).takeUnretainedValue()
                let s = tones.square
                context.setFillColor(tones.dark)
                context.fill(CGRect(x: 0, y: 0, width: 2 * s, height: 2 * s))
                context.setFillColor(tones.light)
                context.fill([CGRect(x: 0, y: s, width: s, height: s), CGRect(x: s, y: 0, width: s, height: s)])
            },
            releaseInfo: { info in if let info { Unmanaged<Tones>.fromOpaque(info).release() } })
        guard let pattern = CGPattern(
            info: tones.toOpaque(), bounds: CGRect(x: 0, y: 0, width: 2 * square, height: 2 * square),
            matrix: .identity, xStep: 2 * square, yStep: 2 * square, tiling: .constantSpacing, isColored: true,
            callbacks: &callbacks), let space = CGColorSpace(patternBaseSpace: nil)
        else {
            tones.release()
            return nil
        }
        var alpha: CGFloat = 1
        return CGColor(patternSpace: space, pattern: pattern, components: &alpha)
    }
}

/// The checker tones and square size a pattern draws with.
private final class Tones {
    let light: CGColor, dark: CGColor, square: CGFloat
    init(light: CGColor, dark: CGColor, square: CGFloat) { (self.light, self.dark, self.square) = (light, dark, square) }
}

/// A view that never takes the pointer, so the viewport's own gestures get every click on the checkerboard.
private final class PassThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
