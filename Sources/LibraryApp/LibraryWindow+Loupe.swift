// LibraryWindow+Loupe.swift: the loupe area (loupe-viewport LV-8). The View
// menu: Grid, Loupe, Sort By, Zoom In and Zoom Out (Larger and Smaller
// Thumbnails in the grid; zoom steps in the loupe, against the fit scale the
// loupe view measured), Zoom to Fit, Actual Size, and Home and End (the first
// and last photo in the sort). An item with nothing to do gets a nil action,
// so it disables. When the loupe's photo changes, the catalog shows the grid
// thumbnail as a preview at once, then the screen-size render runs on the
// loupe service through a RenderQueue (one running, the latest waiting) off
// the main actor; its result goes back through showLoupeRender or
// failLoupeRender, which keep only the current token's (latest wins). The
// neighbours are decoded ahead so stepping is quick. Every state change is a
// LibraryCatalog method.
import AppKit
import LibraryModel
import SwiftUI

/// A finished loupe render (or its failure) under the token it was asked for.
struct LoupeRenderResult: Sendable {
    let token: Int
    let result: Result<RenderedPhoto, LibraryError>
}

final class LoupeAreaState {
    /// Runs the renders one at a time; a newer one replaces an older waiting one.
    let queue = RenderQueue()
    /// The fit scale the loupe view last measured; Zoom In and Out step from it.
    var fitScale = 1.0
    /// Finished renders, handed to the catalog on the main actor.
    let results: AsyncStream<LoupeRenderResult>
    let deliver: AsyncStream<LoupeRenderResult>.Continuation
    /// True once the main-actor task reading `results` runs.
    var listening = false

    init() {
        let made = AsyncStream.makeStream(of: LoupeRenderResult.self)
        results = made.stream
        deliver = made.continuation
    }

    deinit { deliver.finish() }
}

extension LibraryWindow {
    var viewMenu: LibraryMenu.Viewing {
        let inGrid = model.mode == .grid
        let inLoupe = model.mode == .loupe && model.loupeItem != nil
        let scale = model.loupeZoom.scale(fit: areas.loupe.fitScale)
        let canZoomIn = LoupeZoom.steps.contains { $0 > scale * 1.0001 }
        let canZoomOut = LoupeZoom.steps.contains { $0 < scale / 1.0001 }
        return LibraryMenu.Viewing(
            grid: enabled(model.mode == .loupe) { model.showGrid() },
            loupe: enabled(inGrid && !model.isSelectedCollectionEmpty) { model.showLoupe() },
            zoomIn: inGrid
                ? enabled(model.canShowLargerThumbnails) { model.stepCellSize(by: 1) }
                : enabled(inLoupe && canZoomIn) { model.stepZoom(by: 1, fitScale: areas.loupe.fitScale) },
            zoomOut: inGrid
                ? enabled(model.canShowSmallerThumbnails) { model.stepCellSize(by: -1) }
                : enabled(inLoupe && canZoomOut) { model.stepZoom(by: -1, fitScale: areas.loupe.fitScale) },
            zoomToFit: enabled(inLoupe && model.loupeZoom != .fit) { model.zoomLoupe(.fit) },
            actualSize: enabled(inLoupe && model.loupeZoom != .actual) { model.zoomLoupe(.actual) },
            setSort: enabled(!model.order.isEmpty) { (sort: LibrarySort) in model.setSort(sort) }, sort: model.sort,
            first: enabled(inLoupe && model.canShowPreviousInLoupe) { model.showFirstInLoupe() },
            last: enabled(inLoupe && model.canShowNextInLoupe) { model.showLastInLoupe() },
            zoomInTitle: model.zoomInTitle, zoomOutTitle: model.zoomOutTitle,
            zoomTo: enabled(inLoupe) { (scale: Double) in loupeAreaZoom(to: scale) },
            fitMeasured: { fit in areas.loupe.fitScale = fit })
    }

    /// Called when `model.focusedItemID` or `model.mode` changes (the loupe's
    /// photo, or the loupe opening on the photo the grid had focused): the held
    /// thumbnail as a preview, then the full render and the neighbours.
    func loupeAreaFocusChanged() {
        guard model.mode == .loupe else { return }
        model.loupeFocusChanged()
        loupeAreaRender(.full)
        loupeAreaPrefetch()
    }

    /// The canvas's pinch and its own zoom keys: its fit scale is Zoom to Fit.
    private func loupeAreaZoom(to scale: Double) {
        model.zoomLoupe(abs(scale - areas.loupe.fitScale) < 0.0001 ? .fit : .scale(scale))
    }

    /// The screen's long side in pixels: the size the loupe renders at.
    private var loupeLongSide: Int {
        guard let screen = NSScreen.main else { return 2048 }
        let side = max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor
        return side.isFinite && side >= 1 ? Int(side) : 2048
    }

    /// Asks the catalog for the render it needs and runs it through the queue
    /// off the main actor; the result lands under its token.
    private func loupeAreaRender(_ quality: RenderQuality) {
        guard let request = model.loupeRequest(longSide: loupeLongSide, quality: quality) else { return }
        let state = areas.loupe
        loupeAreaListen(state)
        let service = model.services.loupe
        let deliver = state.deliver
        let queue = state.queue
        Task.detached(priority: .userInitiated) {
            await queue.submit(token: request.token) {
                let result: Result<RenderedPhoto, LibraryError>
                do {
                    result = .success(try await service.render(
                        request.photo, settings: request.settings, longSide: request.longSide,
                        quality: request.quality))
                } catch {
                    result = .failure(error as? LibraryError ?? .renderFailed("the photo couldn't be drawn"))
                }
                deliver.yield(LoupeRenderResult(token: request.token, result: result))
            }
        }
    }

    /// Starts, once, the main-actor task that hands finished renders to the catalog.
    private func loupeAreaListen(_ state: LoupeAreaState) {
        guard !state.listening else { return }
        state.listening = true
        let results = state.results
        Task {
            for await finished in results {
                switch finished.result {
                case .success(let render): model.showLoupeRender(render, token: finished.token)
                case .failure(let error): model.failLoupeRender(error, token: finished.token)
                }
            }
        }
    }

    /// Decodes the photos before and after the loupe's ahead, off the main actor.
    private func loupeAreaPrefetch() {
        let neighbours = model.neighboursToPrefetch()
        guard !neighbours.isEmpty else { return }
        let service = model.services.loupe
        let longSide = loupeLongSide
        Task.detached(priority: .utility) {
            await service.prefetch(neighbours, longSide: longSide)
        }
    }
}
