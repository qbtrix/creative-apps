// LibraryWindow+Thumbnails.swift: the thumbnails area (thumbnails TH-6). The
// grid reports the cells on screen and its cell size at the window's display
// scale; the catalog turns them into ThumbnailRequests (the size bucket, never
// a request twice); each request runs on the thumbnails service off the main
// actor, and its image or error goes back through setThumbnail or
// failThumbnail, which drop an answer that is no longer wanted.
import LibraryModel
import SwiftUI

final class ThumbnailsAreaState {
    /// The ids the grid last reported on screen, asked again when the bucket changes.
    var visible: [String] = []
    /// The cell width and display scale the bucket was last set from.
    var cell: (size: Int, scale: Int)?
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
        runThumbnailRequests(model.requestThumbnails(visible: ids))
    }

    /// A new cell size or display scale: the bucket, then the visible cells again.
    private func thumbnailsCellSizeChanged(_ size: Int, scale: Int) {
        let state = areas.thumbnails
        if let cell = state.cell, cell.size == size, cell.scale == scale { return }
        state.cell = (size, scale)
        _ = model.thumbnailLongSide(forCell: size, scale: scale)
        guard !state.visible.isEmpty else { return }
        runThumbnailRequests(model.requestThumbnails(visible: state.visible))
    }

    /// Each request on the thumbnails service off the main actor; its result back on it.
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
                switch result {
                case .success(let image): model.setThumbnail(image, for: request)
                case .failure(let error): model.failThumbnail(request, error)
                }
            }
        }
    }
}
