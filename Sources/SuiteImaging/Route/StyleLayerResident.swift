// StyleLayerResident.swift: one styled layer kept on a render dispatcher
// (layer-styles HY-7). The layer's pixels upload only when its content key
// changes, so a style-only step (a Glow Size scrub) uploads nothing and runs
// just the style draw (StyleRoute.draw on the GPU). The styled result is cut
// back to the layer's own window, centred in the padding the draw adds. No
// style, or a draw that throws (StyleRoute until LS-9), shows the resident
// layer unstyled, so nothing disappears. Linux-safe: the CPU backend runs it in tests.
import CoreRaster
import CoreRender

public final class StyleLayerResident<Content: Hashable> {
    /// What a step shows: the styled layer (released by `finish`) or the resident layer as it is.
    public enum Step: Equatable {
        case styled(RenderSurface), unstyled(RenderSurface)
    }

    /// A window inside a surface.
    public struct Window: Equatable, Sendable {
        public var x, y, width, height: Int
        public init(x: Int, y: Int, width: Int, height: Int) { (self.x, self.y, self.width, self.height) = (x, y, width, height) }
    }

    let dispatcher: RenderDispatcher
    private var resident: (content: Content, surface: RenderSurface)?
    /// Layer uploads so far: one per content change, none per style step.
    public private(set) var uploads = 0

    public init(dispatcher: RenderDispatcher) { self.dispatcher = dispatcher }

    deinit { if let resident { dispatcher.release(resident.surface) } }

    /// The layer for `content` (`pixels` uploaded only when it differs from
    /// the resident one) drawn with `style` by `draw`. Throws only what
    /// `pixels` or the upload throws.
    public func step(
        content: Content, pixels: () throws -> PixelBuffer, style: LayerStyle?,
        draw: (LayerStyle, RenderSurface) throws -> RenderSurface
    ) throws -> Step {
        let layer = try surface(content, pixels)
        guard let style, style != .none else { return .unstyled(layer) }
        do {
            let styled = try draw(style, layer)
            defer { if styled != layer { dispatcher.release(styled) } }
            let w = Self.window(styled: (styled.width, styled.height), layer: (layer.width, layer.height))
            return .styled(try dispatcher.cropped(styled, x: w.x, y: w.y, width: w.width, height: w.height))
        } catch {
            return .unstyled(layer)
        }
    }

    /// Releases what `step` made for one draw; the resident layer stays.
    public func finish(_ step: Step) {
        if case .styled(let surface) = step { dispatcher.release(surface) }
    }

    /// The layer's window in a styled result padded evenly around it, clamped inside the result.
    public static func window(styled: (Int, Int), layer: (Int, Int)) -> Window {
        let (width, height) = (min(layer.0, styled.0), min(layer.1, styled.1))
        return Window(x: max((styled.0 - width) / 2, 0), y: max((styled.1 - height) / 2, 0), width: width, height: height)
    }

    private func surface(_ content: Content, _ pixels: () throws -> PixelBuffer) throws -> RenderSurface {
        if let resident, resident.content == content { return resident.surface }
        if let resident { dispatcher.release(resident.surface) }
        resident = nil
        let made = try dispatcher.surface(try pixels())
        resident = (content, made)
        uploads += 1
        return made
    }
}
