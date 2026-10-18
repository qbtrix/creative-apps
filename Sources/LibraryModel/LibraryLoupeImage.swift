// LibraryLoupeImage.swift: the loupe's picture state in LibraryCatalog
// (loupe-viewport LV-2). A focus change shows the held grid thumbnail as a
// preview at once; each render the loupe asks for gets a new token, and only
// the current token's render or failure lands (latest wins). A failure keeps
// the last picture and says why. The loupe's neighbours are decoded ahead so
// stepping is quick. Linux-safe.

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
        let thumbnails = cache?.thumbnails ?? self.thumbnails
        let held = mode == .loupe ? focusedItemID.flatMap { thumbnails[$0] } : nil
        loupeRender = held.map { RenderedPhoto(image: $0, histogram: .empty, quality: .preview) }
    }

    /// The render the loupe needs now at `longSide`, under a new token; nil outside the loupe.
    public mutating func loupeRequest(longSide: Int, quality: RenderQuality) -> LoupeRequest? {
        guard let photo = loupeItem else { return nil }
        loupeRenderToken &+= 1
        return LoupeRequest(photo: photo, settings: photo.develop, longSide: longSide,
                            quality: quality, token: loupeRenderToken)
    }

    /// Shown only for the current token (latest wins); a `.preview` never replaces a `.full` of the same token.
    public mutating func showLoupeRender(_ render: RenderedPhoto, token: Int) {
        guard token == loupeRenderToken else { return }
        if loupeRender?.quality == .full && render.quality == .preview { return }
        loupeRender = render
        loupeError = nil
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
