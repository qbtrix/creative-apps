// LibraryWindow+Thumbnails.swift: the thumbnails area (thumbnails TH-6). The
// grid reports the cells on screen and its cell size at the window's display
// scale; the store turns them into ThumbnailRequests (the size bucket, never
// a request twice); each request runs on the thumbnails service off the main
// actor, and its image or error goes back as soon as it lands, through
// applyThumbnails, which drops an answer that is no longer wanted. One task
// per request, the shape the grid journey passed with: a pass gathered in one
// task group left every cell loading (#2749). The images live in a store the
// window's body never reads (#2709), so an answer reruns only the grid.
import LibraryModel
import SwiftUI

/// The window's thumbnails: a LibraryThumbnailCache the grid reads through
/// `thumbnails`, which changes only when the held images do, so a pass that
/// only records requests reruns nothing.
@Observable final class LibraryThumbnailStore {
    private(set) var thumbnails: [String: DisplayImage] = [:]
    @ObservationIgnored private(set) var cache = LibraryThumbnailCache()

    func cellSizeChanged(_ size: Int, scale: Int) {
        _ = cache.thumbnailLongSide(forCell: size, scale: scale)
    }

    /// Requests for the visible cells without a current image; evicts far ones.
    func request(visible: [String], in catalog: LibraryCatalog) -> [ThumbnailRequest] {
        let requests = cache.requestThumbnails(visible: visible, in: catalog)
        publish()
        return requests
    }

    /// A pass's answers; returns the failed photos' new availability for the catalog.
    func apply(
        _ results: [(request: ThumbnailRequest, result: Result<DisplayImage, LibraryError>)], in catalog: LibraryCatalog
    ) -> [String: PhotoAvailability] {
        let failures = cache.applyThumbnails(results, in: catalog)
        publish()
        return failures
    }

    /// Drops the held images and requests of `ids` (their develop settings changed).
    func invalidate(_ ids: Set<String>) {
        for id in ids { cache.invalidateThumbnail(id) }
        publish()
    }

    /// Drops every image and request (the catalog was replaced).
    func clear() {
        cache = LibraryThumbnailCache()
        publish()
    }

    private func publish() {
        if thumbnails != cache.thumbnails { thumbnails = cache.thumbnails }
    }
}

final class ThumbnailsAreaState {
    /// The ids the grid last reported on screen, asked again when the bucket changes.
    var visible: [String] = []
    /// The cell width and display scale the bucket was last set from.
    var cell: (size: Int, scale: Int)?
    /// The held images and requests, apart from the catalog.
    let store = LibraryThumbnailStore()
}

extension LibraryWindow {
    var thumbnailsMenu: LibraryMenu.Thumbnails {
        LibraryMenu.Thumbnails(
            visibleChanged: { ids in thumbnailsVisibleChanged(ids) },
            cellSizeChanged: { size, scale in thumbnailsCellSizeChanged(size, scale: scale) })
    }

    /// The cells on screen: requests for those without a current image.
    private func thumbnailsVisibleChanged(_ ids: [String]) {
        areas.thumbnails.visible = ids
        runThumbnailRequests(areas.thumbnails.store.request(visible: ids, in: model))
    }

    /// After a develop edit ends (develop DV-8): drops the held images of
    /// `ids`, then asks again for the cells last reported on screen, so the
    /// grid redraws them without waiting for a scroll or a resize.
    func refreshThumbnails(invalidating ids: Set<String>) {
        let state = areas.thumbnails
        state.store.invalidate(ids)
        guard !state.visible.isEmpty else { return }
        runThumbnailRequests(state.store.request(visible: state.visible, in: model))
    }

    /// A new cell size or display scale: the bucket, then the visible cells again.
    private func thumbnailsCellSizeChanged(_ size: Int, scale: Int) {
        let state = areas.thumbnails
        if let cell = state.cell, cell.size == size, cell.scale == scale { return }
        state.cell = (size, scale)
        state.store.cellSizeChanged(size, scale: scale)
        guard !state.visible.isEmpty else { return }
        runThumbnailRequests(state.store.request(visible: state.visible, in: model))
    }

    /// Each request on the thumbnails service off the main actor; its answer
    /// lands in the store when it arrives, and the catalog changes only when
    /// a file failed.
    private func runThumbnailRequests(_ requests: [ThumbnailRequest]) {
        guard !requests.isEmpty else { return }
        let service = model.services.thumbnails
        var photos: [String: PhotoItem] = [:]
        for photo in model.items { photos[photo.id] = photo }
        for request in requests {
            guard let photo = photos[request.id] else { continue }
            Task {
                let result = await Task.detached(priority: .userInitiated) { () -> Result<DisplayImage, LibraryError> in
                    do {
                        return .success(try await service.thumbnail(for: photo, longSide: request.longSide))
                    } catch {
                        return .failure(error as? LibraryError ?? .renderFailed("the thumbnail couldn't be drawn"))
                    }
                }.value
                let failures = areas.thumbnails.store.apply([(request, result)], in: model)
                if !failures.isEmpty { model.applyThumbnailFailures(failures) }
            }
        }
    }
}
