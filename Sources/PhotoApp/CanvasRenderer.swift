// CanvasRenderer.swift: keeps the canvas picture up to date without blocking
// the window. Each change to the workspace asks for the tiles that changed
// since the picture shown (PhotoRenderer.update), rendered off the main actor;
// a new image or a new size asks for all of them. While a render runs, newer
// requests wait and only the latest is drawn, so a fast brush stroke never
// queues up stale frames. The tiles go straight to the tile layers
// (CanvasTiles), not through SwiftUI, so no whole-canvas buffer or picture
// exists per event. `revision` says what is shown; the render time reaches the
// status line at most four times a second, so the readout doesn't redraw the
// window every frame. A failed render keeps the last good picture and its
// message. Presentation state only: it never changes the workspace.
import CoreGraphics
import Foundation
import Observation
import PhotoModel

@MainActor @Observable
final class CanvasRenderer {
    let tiles = CanvasTiles()
    /// The revision the tiles show; nil with no image.
    private(set) var revision: Int?
    /// The latest render's time, published at most every `timing`.
    private(set) var milliseconds: Double?
    private(set) var failure: String?
    /// The latest render's time, every render.
    @ObservationIgnored private(set) var lastMilliseconds: Double?
    @ObservationIgnored private var timed = ContinuousClock.now - timing
    private static let timing = Duration.milliseconds(250)
    private var isRendering = false
    private var waiting: PhotoWorkspace?

    /// Draws `workspace` once the render in flight, if any, is done.
    func show(_ workspace: PhotoWorkspace) {
        guard let canvas = workspace.canvas else {
            tiles.clear()
            (revision, milliseconds, waiting) = (nil, nil, nil)
            return
        }
        guard !isRendering else {
            waiting = workspace
            return
        }
        isRendering = true
        let sameSize = canvas.width == tiles.width && canvas.height == tiles.height
        let since = sameSize ? revision : nil
        Task {
            do {
                let update = try await PhotoRenderer.update(workspace, since: since)
                tiles.apply(update)
                lastMilliseconds = update.milliseconds
                if ContinuousClock.now - timed >= Self.timing {
                    (milliseconds, timed) = (update.milliseconds, .now)
                }
                failure = nil
                revision = update.revision
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

    /// 8-bit sRGB bytes as an image. `alpha` is `.last` for straight alpha,
    /// `.premultipliedLast` for premultiplied, `.noneSkipLast` for opaque pixels.
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
