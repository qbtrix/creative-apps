// LibraryWindow+Thumbnails.swift: the thumbnails area (thumbnails TH-6). The
// grid reports the cells on screen and its cell size at the window's display
// scale; the catalog turns them into ThumbnailRequests (the size bucket, never
// a request twice); a pass's requests run together on the thumbnails service
// off the main actor, and their images and errors go back in one
// applyThumbnails change, which drops an answer that is no longer wanted.
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

    /// A pass's requests on the thumbnails service off the main actor, together;
    /// their answers land in one catalog change, so the window body runs once
    /// per pass instead of once per image.
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
            model.applyThumbnails(results)
        }
    }
}
