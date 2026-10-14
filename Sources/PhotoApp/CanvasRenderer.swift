// CanvasRenderer.swift: keeps the canvas picture up to date without blocking
// the window. Each change to the workspace asks for a frame; PhotoRenderer
// makes it off the main actor, redrawing only what changed since the last
// one. While a render runs, newer requests wait and only the latest is drawn,
// so a fast brush stroke never queues up stale frames. The frame becomes a
// CGImage (sRGB, straight alpha) for the canvas, and its time goes to the
// status line at most four times a second, so the readout doesn't redraw the
// window every frame. The frame itself is kept outside observation: the
// Observation macro compares an Equatable value before it notifies, which for
// a frame means comparing every byte of the canvas. A failed render keeps the
// last good picture and its message. Presentation state only: it never
// changes the workspace.
import CoreGraphics
import Foundation
import Observation
import PhotoModel

@MainActor @Observable
final class CanvasRenderer {
    private(set) var image: CGImage?
    /// The latest render's time, published at most every `timing`.
    private(set) var milliseconds: Double?
    private(set) var failure: String?
    @ObservationIgnored private(set) var frame: PhotoFrame?
    @ObservationIgnored private var timed = ContinuousClock.now - timing
    private static let timing = Duration.milliseconds(250)
    private var isRendering = false
    private var waiting: PhotoWorkspace?

    /// Draws `workspace` once the render in flight, if any, is done.
    func show(_ workspace: PhotoWorkspace) {
        guard workspace.canvas != nil else {
            (image, frame, milliseconds, waiting) = (nil, nil, nil, nil)
            return
        }
        guard !isRendering else {
            waiting = workspace
            return
        }
        isRendering = true
        let previous = frame
        Task {
            do {
                let next = try await PhotoRenderer.render(workspace, after: previous)
                frame = next
                image = Self.image(next)
                if ContinuousClock.now - timed >= Self.timing {
                    (milliseconds, timed) = (next.milliseconds, .now)
                }
                failure = nil
            } catch {
                failure = "The picture couldn't be drawn: \(error)"
            }
            isRendering = false
            if let latest = waiting {
                waiting = nil
                show(latest)
            }
        }
    }

    /// A frame's bytes as an image; nil only if CoreGraphics refuses them.
    nonisolated static func image(_ frame: PhotoFrame) -> CGImage? {
        image(rgba8: frame.rgba8, width: frame.width, height: frame.height, alpha: .last)
    }

    /// 8-bit sRGB bytes as an image. `alpha` is `.last` for straight alpha,
    /// `.noneSkipLast` for opaque pixels.
    nonisolated static func image(rgba8: [UInt8], width: Int, height: Int, alpha: CGImageAlphaInfo) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let provider = CGDataProvider(data: Data(rgba8) as CFData)
        else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: alpha.rawValue), provider: provider, decode: nil,
            shouldInterpolate: true, intent: .defaultIntent)
    }
}
