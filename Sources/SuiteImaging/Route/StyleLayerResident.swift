// StyleLayerResident.swift (layer-styles HY-7): one styled layer kept on a render dispatcher. Its pixels upload
// only when its content key changes, so a style-only step runs just the style draw, cut back to the layer's window.
// No style, or a draw that throws (StyleRoute until LS-9), shows the layer unstyled. Linux-safe.
import CoreRaster
import CoreRender

public final class StyleLayerResident<Content: Hashable> {
    /// What a step shows: the styled layer (released by `finish`) or the resident layer as it is.
    public enum Step: Equatable { case styled(RenderSurface), unstyled(RenderSurface) }
    public let dispatcher: RenderDispatcher
    private var resident: (content: Content, surface: RenderSurface)?
    /// Layer uploads so far: one per content change, none per style step.
    public private(set) var uploads = 0
    public init(dispatcher: RenderDispatcher) { self.dispatcher = dispatcher }
    deinit { if let resident { dispatcher.release(resident.surface) } }

    /// The layer for `content` (`pixels` read only when it is new) drawn with `style` by `draw`.
    public func step(content: Content, pixels: () throws -> PixelBuffer, style: LayerStyle?,
                     draw: (LayerStyle, RenderSurface) throws -> RenderSurface) throws -> Step {
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

    /// Releases what `step` made; the resident layer stays.
    public func finish(_ step: Step) {
        if case .styled(let surface) = step { dispatcher.release(surface) }
    }

    /// The layer's window in a result padded evenly around it, clamped inside the result.
    public static func window(styled: (Int, Int), layer: (Int, Int)) -> (x: Int, y: Int, width: Int, height: Int) {
        let (width, height) = (min(layer.0, styled.0), min(layer.1, styled.1))
        return (x: max((styled.0 - width) / 2, 0), y: max((styled.1 - height) / 2, 0), width: width, height: height)
    }

    private func surface(_ content: Content, _ pixels: () throws -> PixelBuffer) throws -> RenderSurface {
        if let resident, resident.content == content { return resident.surface }
        if let resident { dispatcher.release(resident.surface) }
        resident = nil
        let made = try dispatcher.surface(try pixels())
        (resident, uploads) = ((content, made), uploads + 1)
        return made
    }
}
