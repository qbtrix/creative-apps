// LibraryWindow+Thumbnails.swift: the thumbnails area (thumbnails TH-6). The
// grid reports the cells on screen and its cell size at the window's display
// scale; the store turns them into ThumbnailRequests (the size bucket, never
// a request twice); each request runs on the thumbnails service off the main
// actor, and its image or error goes back as soon as it lands, through
// applyThumbnails, which drops an answer that is no longer wanted. One task
// per request, the shape the grid journey passed with: a pass gathered in one
// task group left every cell loading (#2749). The images live in a store the
// window's body never reads (#2709), so an answer reruns only the grid.
// A scroll asks two screens either side too and cancels the requests it left
// behind, so a fast scroll through 10,000 photos never queues a decode it no
// longer needs (large-catalog LG-5, #3108).
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

    /// A scroll's pass: the visible cells, then two screens either side; the
    /// pending requests it left behind come back cancelled.
    func pass(visible: [String], in catalog: LibraryCatalog) -> ThumbnailPass {
        let pass = cache.thumbnailPass(visible: visible, in: catalog)
        publish()
        return pass
    }

    /// The photo with `id`, through the cache's position map.
    func photo(_ id: String, in catalog: LibraryCatalog) -> PhotoItem? {
        cache.photo(id, in: catalog)
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
    /// The decode running for each request, cancelled when a scroll leaves it.
    var tasks: [ThumbnailRequest: Task<Void, Never>] = [:]
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
        runThumbnailPass(visible: ids)
    }

    /// After a develop edit ends (develop DV-8): drops the held images of
    /// `ids`, then asks again for the cells last reported on screen, so the
    /// grid redraws them without waiting for a scroll or a resize.
    func refreshThumbnails(invalidating ids: Set<String>) {
        let state = areas.thumbnails
        state.store.invalidate(ids)
        guard !state.visible.isEmpty else { return }
        runThumbnailPass(visible: state.visible)
    }

    /// A new cell size or display scale: the bucket, then the visible cells again.
    private func thumbnailsCellSizeChanged(_ size: Int, scale: Int) {
        let state = areas.thumbnails
        if let cell = state.cell, cell.size == size, cell.scale == scale { return }
        state.cell = (size, scale)
        state.store.cellSizeChanged(size, scale: scale)
        guard !state.visible.isEmpty else { return }
        runThumbnailPass(visible: state.visible)
    }

    /// A pass over `visible`: cancels the decodes it left behind, then runs its requests.
    private func runThumbnailPass(visible: [String]) {
        let state = areas.thumbnails
        let pass = state.store.pass(visible: visible, in: model)
        for request in pass.cancelled { state.tasks.removeValue(forKey: request)?.cancel() }
        runThumbnailRequests(pass.requests)
    }

    /// Each request on the thumbnails service off the main actor; its answer
    /// lands in the store when it arrives, and the catalog changes only when
    /// a file failed. Cancelling a request's task cancels its decode.
    private func runThumbnailRequests(_ requests: [ThumbnailRequest]) {
        let service = model.services.thumbnails
        let state = areas.thumbnails
        for request in requests {
            guard let photo = state.store.photo(request.id, in: model) else { continue }
            state.tasks[request] = Task {
                let decode = Task.detached(priority: .userInitiated) { () -> Result<DisplayImage, LibraryError> in
                    do {
                        return .success(try await service.thumbnail(for: photo, longSide: request.longSide))
                    } catch {
                        return .failure(error as? LibraryError ?? .renderFailed("the thumbnail couldn't be drawn"))
                    }
                }
                let result = await withTaskCancellationHandler { await decode.value } onCancel: { decode.cancel() }
                guard !Task.isCancelled else { return }  // the scroll already dropped it
                areas.thumbnails.tasks[request] = nil
                let failures = areas.thumbnails.store.apply([(request, result)], in: model)
                if !failures.isEmpty { model.applyThumbnailFailures(failures) }
            }
        }
    }
}
