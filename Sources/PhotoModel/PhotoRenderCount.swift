// PhotoRenderCount.swift: debug-only counts of the render work Photo does, for the idle-work and budget
// tests (AppSnapshotTests' IdleWorkTests). `regions` is every region a route composites (a CPU tile, a GPU
// band, a histogram row) and `layerComposites` every layer laid onto one, on every route: the dispatcher
// route, the resident batch, the live route's steps and the CoreRaster reference. The counters are
// process-wide, so a suite that reads them nests in BodyCountSuites like the body counters. In release
// the calls compile to nothing. Linux-safe.
import Synchronization

public enum PhotoRenderCount {
    #if DEBUG
    public static let regions = Mutex(0)
    public static let layerComposites = Mutex(0)
    #endif

    /// One more region composited.
    @inline(__always) static func region() {
        #if DEBUG
        regions.withLock { $0 += 1 }
        #endif
    }

    /// `count` more layers laid onto a region.
    @inline(__always) static func layers(_ count: Int) {
        #if DEBUG
        layerComposites.withLock { $0 += count }
        #endif
    }
}
