// LibraryWindow+Loupe.swift: the loupe area (loupe-viewport LV-8). The View
// menu: Grid, Loupe, Sort By, Zoom In and Zoom Out (Larger and Smaller
// Thumbnails in the grid; zoom steps in the loupe, against the fit scale the
// loupe view measured), Zoom to Fit, Actual Size, and Home and End (the first
// and last photo in the sort). An item with nothing to do gets a nil action,
// so it disables. When the loupe's photo changes, the catalog shows the grid
// thumbnail as a preview at once, then the screen-size render runs on the
// loupe service through a RenderQueue (one running, the latest waiting) off
// the main actor; its result goes back through showLoupeRender or
// failLoupeRender, which keep only the current token's (latest wins). On the
// GPU route (suite-imaging IM-11) the result is a GPU frame instead, through
// showLoupeFrame, and a failed GPU write renders again on the CPU. A frame's
// histogram runs after it on a second queue (latest wins) and lands through
// showLoupeHistogram, so a slider step never waits on a CPU develop. The
// neighbours decode ahead behind that render on the same queue, and a newer
// step drops an older step's pending ones (LG-6). Every state change is a
// LibraryCatalog method; each menu item runs a `LibraryAction`.
import AppKit
import LibraryModel
import SwiftUI

/// A finished loupe render (or its failure), or a GPU frame's histogram, under the token it was asked for.
struct LoupeRenderResult: Sendable {
    let token: Int
    let result: Result<LoupePicture, LibraryError>
}

/// A GPU frame's developed histogram under its frame's token.
struct LoupeHistogramResult: Sendable {
    let token: Int
    let histogram: HistogramBins
}

/// What the loupe shows: CPU pixels, or a GPU frame the loupe's view writes.
enum LoupePicture: Sendable {
    case render(RenderedPhoto), frame(LoupeGPUFrame)

    /// `request`'s picture at `settings`: the GPU frame when `preferGPU` and the
    /// steps allow it (suite-imaging IM-11), else the CPU render. `failure` is
    /// the reason when an error says none.
    static func make(_ request: LoupeRequest, settings: DevelopSettings, preferGPU: Bool,
                     service: any LoupeImaging, failure: String) async -> Result<LoupePicture, LibraryError> {
        do {
            if let frame = try await service.gpuFrame(
                request.photo, settings: settings, longSide: request.longSide, preferGPU: preferGPU) {
                return .success(.frame(frame))
            }
            return .success(.render(try await service.render(
                request.photo, settings: settings, longSide: request.longSide, quality: request.quality)))
        } catch {
            return .failure(error as? LibraryError ?? .renderFailed(failure))
        }
    }

    /// After a GPU frame, its histogram at `settings` on `queue` (latest wins), yielded under `request`'s
    /// token; a CPU render carries its own. Every path that shows a frame calls this, or the histogram stays
    /// on the last one's bins.
    static func histogram(after result: Result<LoupePicture, LibraryError>, _ request: LoupeRequest,
                          settings: DevelopSettings, service: any LoupeImaging, queue: RenderQueue,
                          deliver: AsyncStream<LoupeHistogramResult>.Continuation) {
        guard case .success(.frame) = result else { return }
        Task.detached(priority: .utility) {
            await queue.submit(token: request.token) {
                guard let bins = try? await service.histogram(request.photo, settings: settings) else { return }
                deliver.yield(LoupeHistogramResult(token: request.token, histogram: bins))
            }
        }
    }
}

/// Observable for `fitScale` alone, so the zoom pill and the menu's zoom
/// items follow a new fit (a resize, a new photo) the moment it is measured.
@Observable final class LoupeAreaState {
    /// Runs the renders one at a time; a newer one replaces an older waiting one.
    @ObservationIgnored let queue = RenderQueue()
    /// Runs GPU frames' histograms apart from `queue`, so a frame never waits on one.
    @ObservationIgnored let histograms = RenderQueue()
    /// The fit scale the loupe view last measured; Zoom In and Out step from it.
    var fitScale = 1.0
    /// Finished renders, handed to the catalog on the main actor.
    @ObservationIgnored let results: AsyncStream<LoupeRenderResult>
    @ObservationIgnored let deliver: AsyncStream<LoupeRenderResult>.Continuation
    /// Finished histograms, handed to the catalog on the main actor.
    @ObservationIgnored let histogramResults: AsyncStream<LoupeHistogramResult>
    @ObservationIgnored let deliverHistogram: AsyncStream<LoupeHistogramResult>.Continuation
    /// True once the main-actor task reading `results` runs.
    @ObservationIgnored var listening = false

    init() {
        let made = AsyncStream.makeStream(of: LoupeRenderResult.self)
        results = made.stream
        deliver = made.continuation
        let histograms = AsyncStream.makeStream(of: LoupeHistogramResult.self)
        histogramResults = histograms.stream
        deliverHistogram = histograms.continuation
    }

    deinit {
        deliver.finish()
        deliverHistogram.finish()
    }
}

extension LibraryWindow {
    var viewMenu: LibraryMenu.Viewing {
        let fit = areas.loupe.fitScale
        return LibraryMenu.Viewing(
            grid: act(.showGrid),
            loupe: act(.showLoupe),
            zoomIn: act(.zoomIn(fitScale: fit)),
            zoomOut: act(.zoomOut(fitScale: fit)),
            zoomToFit: act(.zoomToFit),
            actualSize: act(.actualSize),
            setSort: enabled(model.help(.setSort(model.sort)) == nil) { (sort: LibrarySort) in
                try? model.run(.setSort(sort))
            }, sort: model.sort,
            setCellSize: { (size: Int) in try? model.run(.setCellSize(size)) },
            first: act(.showFirst),
            last: act(.showLast),
            zoomInTitle: model.zoomInTitle, zoomOutTitle: model.zoomOutTitle,
            zoomTo: enabled(model.help(.zoomTo(1, fitScale: fit)) == nil) { (scale: Double) in
                try? model.run(.zoomTo(scale, fitScale: areas.loupe.fitScale))
            },
            fitMeasured: { fit in if areas.loupe.fitScale != fit { areas.loupe.fitScale = fit } })
    }

    /// Called when `model.focusedItemID` or `model.mode` changes (the loupe's
    /// photo, or the loupe opening on the photo the grid had focused): the held
    /// thumbnail as a preview, then the full render and the neighbours.
    func loupeAreaFocusChanged() {
        guard model.mode == .loupe else { return }
        model.loupeFocusChanged(from: areas.thumbnails.store.cache)
        loupeAreaRender(.full, prefetching: model.neighboursToPrefetch())
    }

    /// The screen's long side in pixels: the size the loupe renders at.
    private var loupeLongSide: Int {
        guard let screen = NSScreen.main else { return 2048 }
        let side = max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor
        return side.isFinite && side >= 1 ? Int(side) : 2048
    }

    /// Asks the catalog for the render it needs and runs it through the queue
    /// off the main actor; the result lands under its token. `neighbours`
    /// replace the queue's pending decodes ahead; nil keeps them.
    func loupeAreaRender(_ quality: RenderQuality, prefetching neighbours: [PhotoItem]? = nil) {
        guard let request = model.loupeRequest(longSide: loupeLongSide, quality: quality) else { return }
        let state = areas.loupe
        loupeAreaListen(state)
        let service = model.services.loupe
        let deliver = state.deliver
        let queue = state.queue, histograms = state.histograms, deliverHistogram = state.deliverHistogram
        let preferGPU = loupeGPU?.prefersGPU ?? false
        let longSide = request.longSide
        let ahead = neighbours.map { photos in
            RenderQueue.Ahead(photos) { await service.prefetch([$0], longSide: longSide) }
        }
        Task.detached(priority: .userInitiated) {
            await queue.submit(token: request.token, prefetching: ahead) {
                let result = await LoupePicture.make(
                    request, settings: request.settings, preferGPU: preferGPU, service: service,
                    failure: "the photo couldn't be drawn")
                deliver.yield(LoupeRenderResult(token: request.token, result: result))
                LoupePicture.histogram(after: result, request, settings: request.settings, service: service,
                                       queue: histograms, deliver: deliverHistogram)
            }
        }
    }

    /// Starts, once, the main-actor task that hands finished renders to the catalog.
    private func loupeAreaListen(_ state: LoupeAreaState) {
        guard !state.listening else { return }
        state.listening = true
        let results = state.results, histograms = state.histogramResults
        Task {
            for await finished in histograms { model.showLoupeHistogram(finished.histogram, token: finished.token) }
        }
        Task {
            for await finished in results {
                switch finished.result {
                case .success(.render(let render)): model.showLoupeRender(render, token: finished.token)
                case .success(.frame(let frame)): model.showLoupeFrame(frame, token: finished.token)
                case .failure(let error): model.failLoupeRender(error, token: finished.token)
                }
            }
        }
    }
}
