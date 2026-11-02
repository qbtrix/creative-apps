// LibraryLoupeImage.swift: the loupe's picture state in LibraryCatalog
// (loupe-viewport LV-2). A focus change shows the held grid thumbnail as a
// preview at once; each render the loupe asks for gets a new token. A render
// lands when its token is at least the shown picture's (newer wins), so a
// develop drag's previews show while the drag goes on, even when the next
// sample has already asked for another; a render asked for before the last
// focus change never lands, and a preview never replaces a full of the same
// token. A failure keeps the last picture and says why, for the current token
// only. The loupe's neighbours are decoded ahead so stepping is quick. A GPU
// frame (suite-imaging IM-11) lands under the same rules as a full render,
// keeping its develop program for the view; a CPU render or a focus change
// drops it. The frame keeps the shown histogram until its own lands
// (`showLoupeHistogram`): one of a shown token newer than the last, so a
// drag's histograms follow it, and never one from before a focus change.
// Linux-safe.

/// One render the loupe needs: which photo, with which settings, at what
/// size and quality, under the token its result must match to be shown.
public struct LoupeRequest: Sendable, Hashable {
    public var photo: PhotoItem
    public var settings: DevelopSettings
    public var longSide: Int
    public var quality: RenderQuality
    public var token: Int

    public init(photo: PhotoItem, settings: DevelopSettings, longSide: Int, quality: RenderQuality, token: Int) {
        self.photo = photo; self.settings = settings; self.longSide = longSide
        self.quality = quality; self.token = token
    }
}

extension LibraryCatalog {
    /// After the loupe's photo changes: the grid thumbnail as a `.preview` render
    /// (or nil), no error, a new token; the zoom stays (stepping at 100% compares focus).
    /// Reads the thumbnail by the focused id, never scanning `order` or `items` (QB-LIB-5: 1 ms at 10,000),
    /// from `cache` when the window keeps the thumbnails apart, else from the catalog's own.
    public mutating func loupeFocusChanged(from cache: LibraryThumbnailCache? = nil) {
        loupeRenderToken &+= 1
        loupeError = nil
        cropDraft = nil
        let thumbnails = cache?.thumbnails ?? self.thumbnails
        let held = mode == .loupe ? focusedItemID.flatMap { thumbnails[$0] } : nil
        loupeRender = held.map { RenderedPhoto(image: $0, histogram: .empty, quality: .preview) }
        loupeSteps = nil
        loupeShownToken = loupeRenderToken
        loupeHistogramToken = loupeRenderToken
    }

    /// The render the loupe needs now at `longSide`, under a new token; nil outside the loupe.
    public mutating func loupeRequest(longSide: Int, quality: RenderQuality) -> LoupeRequest? {
        guard let photo = loupeItem else { return nil }
        loupeRenderToken &+= 1
        return LoupeRequest(photo: photo, settings: cropLoupeSettings ?? photo.develop, longSide: longSide,
                            quality: quality, token: loupeRenderToken)
    }

    /// Shown when `token` is at least the shown picture's (newer wins, so a drag's
    /// in-flight previews land); a `.preview` never replaces a `.full` of the same token.
    public mutating func showLoupeRender(_ render: RenderedPhoto, token: Int) {
        guard token >= loupeShownToken, token <= loupeRenderToken else { return }
        if token == loupeShownToken && loupeRender?.quality == .full && render.quality == .preview { return }
        loupeRender = render
        loupeSteps = nil
        loupeShownToken = token
        loupeError = nil
    }

    /// `frame`'s base as a `.full` render keeping the shown histogram, and its program for the view to write;
    /// under `showLoupeRender`'s token rules.
    public mutating func showLoupeFrame(_ frame: LoupeGPUFrame, token: Int) {
        guard token >= loupeShownToken, token <= loupeRenderToken else { return }
        loupeRender = RenderedPhoto(image: frame.base, histogram: loupeRender?.histogram ?? .empty, quality: .full)
        loupeSteps = frame.program
        loupeShownToken = token
        loupeError = nil
    }

    /// The developed histogram of the GPU frame shown under `token` or an older one, when newer than the last
    /// histogram shown and asked after the last focus change.
    public mutating func showLoupeHistogram(_ histogram: HistogramBins, token: Int) {
        guard loupeSteps != nil, token <= loupeShownToken, token > loupeHistogramToken, let render = loupeRender else { return }
        loupeRender = RenderedPhoto(image: render.image, histogram: histogram, quality: render.quality)
        loupeHistogramToken = token
    }

    /// Keeps the last picture; sets `loupeError` for the current token only.
    public mutating func failLoupeRender(_ error: LibraryError, token: Int) {
        guard token == loupeRenderToken else { return }
        loupeError = error.message
    }

    /// The photos before and after the loupe's in `order`.
    public func neighboursToPrefetch() -> [PhotoItem] {
        guard mode == .loupe, let id = focusedItemID, let index = order.firstIndex(of: id) else { return [] }
        let ids = [index - 1, index + 1].filter { order.indices.contains($0) }.map { order[$0] }
        return ids.compactMap { neighbour in items.first { $0.id == neighbour } }
    }
}
