// PhotoWindow+Sample.swift: the eyedropper area of a Photo window (eyedropper
// PE-2): its intents and their route. The size chips set the square the tool
// reads; a pick samples the composite through the Model's SampleTarget
// adapter (PhotoSample+Kernel) and makes it the brush colour, with no undo
// step, and a refused pick beeps. A canvas press that picks (LiveStroke's
// `press`) sends one `.pick(at:)` and draws nothing (`samplePress`).
// PhotoSampleLoupe is SuiteUI's SampleLoupe in PhotoCanvasOverlay: with the
// Eyedropper it follows the pointer with the composite's colour under it,
// hollow past the image's edge. PhotoSampleArea is the identity.
import AppKit
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// What the eyedropper area can be asked to do.
enum SampleIntent {
    /// The square the eyedropper reads.
    case size(SampleSize)
    /// Sample the composite at `point` (canvas pixels) into the brush colour.
    case pick(at: Point)
}

extension PhotoWindow {
    func performSample(_ intent: SampleIntent) {
        switch intent {
        case .size(let size): model.setSampleSize(size)
        case .pick(let point):
            do { try model.pickBrushColor(at: point) } catch { NSSound.beep() }
        }
    }

    /// A picking press's drag samples: the first picks, the rest do nothing.
    /// True when `moves` were the pick's, so the window doesn't draw them.
    func samplePress(_ moves: [PhotoStrokeMove]) -> Bool {
        switch liveStroke.press(moves, on: model) {
        case .pick(let point)?:
            performSample(.pick(at: point))
            return true
        case .hold?: return true
        case nil: return false
        }
    }
}

/// The Eyedropper's loupe over the canvas, in PhotoCanvasOverlay's view
/// points: at the pointer's document point at `zoom`, with the colour of the
/// tool's square of the composite there; nothing without the Eyedropper or
/// a pointer. Values in, nothing out.
struct PhotoSampleLoupe: View {
    let model: PhotoWorkspace
    let zoom: Double
    /// The document point under the pointer; nil when it is off the canvas.
    let hover: CGPoint?

    var body: some View {
        if let center { SampleLoupe(color: color, at: center) }
    }

    /// The loupe's centre in view points; nil when it isn't shown.
    var center: CGPoint? {
        guard model.showsSampleLoupe, let hover else { return nil }
        return CGPoint(x: hover.x * zoom, y: hover.y * zoom)
    }

    /// The colour under the pointer as 8-bit sRGB; nil past the image's edge.
    var color: HexColor? {
        guard let hover, let c = model.sampledColor(at: Point(x: hover.x, y: hover.y), size: model.sampleSize)
        else { return nil }
        func byte(_ channel: Double) -> UInt8 { UInt8(clamping: SampleRules.byte(channel)) }
        return HexColor(byte(c.r), byte(c.g), byte(c.b))
    }
}

/// The eyedropper area's state, alerts and dialogs over the window.
struct PhotoSampleArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}
