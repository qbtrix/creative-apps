// LibraryWindow+Thumbnails.swift: the thumbnails area (thumbnails TH-6). The
// grid reports the cells on screen and its cell size at the window's display
// scale; the store turns them into ThumbnailRequests (the size bucket, never
// a request twice); a pass's requests run together on the thumbnails service
// off the main actor, and their images and errors go back in one
// applyThumbnails change, which drops an answer that is no longer wanted.
// The images live in a store the window's body never reads (#2709).
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

    /// A new cell size or display scale: the bucket, then the visible cells again.
    private func thumbnailsCellSizeChanged(_ size: Int, scale: Int) {
        let state = areas.thumbnails
        if let cell = state.cell, cell.size == size, cell.scale == scale { return }
        state.cell = (size, scale)
        state.store.cellSizeChanged(size, scale: scale)
        guard !state.visible.isEmpty else { return }
        runThumbnailRequests(state.store.request(visible: state.visible, in: model))
    }

    /// A pass's requests on the thumbnails service off the main actor, together;
    /// their answers land in the store in one change, and the catalog changes
    /// only when a file failed.
    private func runThumbnailRequests(_ requests: [ThumbnailRequest]) {
        guard !requests.isEmpty else { return }
        let service = model.services.thumbnails
        var photos: [String: PhotoItem] = [:]
        for photo in model.items { photos[photo.id] = photo }
        let jobs = requests.compactMap { request in photos[request.id].map { (request, $0) } }
        Task {
            let results = await Task.detached(priority: .userInitiated) {
                await withTaskGroup(of: (request: ThumbnailRequest, result: Result<DisplayImage, LibraryError>).self) { group in
                    for (request, photo) in jobs {
                        group.addTask {
                            do {
                                return (request, .success(try await service.thumbnail(for: photo, longSide: request.longSide)))
                            } catch {
                                return (request, .failure(error as? LibraryError ?? .renderFailed("the thumbnail couldn't be drawn")))
                            }
                        }
                    }
                    return await group.reduce(into: []) { $0.append($1) }
                }
            }.value
            let failures = areas.thumbnails.store.apply(results, in: model)
            if !failures.isEmpty { model.applyThumbnailFailures(failures) }
        }
    }
}
