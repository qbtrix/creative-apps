// PhotoRenderCount.swift: debug-only counts of the render work Photo does, for the idle-work and budget
// tests (AppSnapshotTests' IdleWorkTests). `regions` is every region a canvas route composites (a CPU tile,
// a GPU band) and `layerComposites` every layer laid onto one; `rows` and `rowLayers` are the same for the
// CoreRaster reference path (a histogram row, an export); `bases` and `hits` are the dispatcher route's kept bases (LiveCompositeCache). The counters are
// process-wide, so a suite that reads them nests in BodyCountSuites like the body counters. In release
// the calls compile to nothing. Linux-safe.
import Synchronization

public enum PhotoRenderCount {
    #if DEBUG
    public static let regions = Mutex(0)
    public static let layerComposites = Mutex(0)
    /// Regions the CoreRaster reference path composited (histogram rows, export, snapshots) and the layers laid
    /// onto them, apart from the canvas routes' so a test can tell a drag's work from a recount's.
    public static let rows = Mutex(0), rowLayers = Mutex(0)
    /// Dispatcher-route bases made (LiveCompositeCache), and regions served from a kept base.
    public static let bases = Mutex(0), hits = Mutex(0)
    #endif

    /// One more region composited.
    @inline(__always) static func region() {
        #if DEBUG
        regions.withLock { $0 += 1 }
        #endif
    }

    /// One more region through the CoreRaster reference path.
    @inline(__always) static func row() {
        #if DEBUG
        rows.withLock { $0 += 1 }
        #endif
    }

    /// `count` more layers laid onto a reference-path region.
    @inline(__always) static func rowLayers(_ count: Int) {
        #if DEBUG
        rowLayers.withLock { $0 += count }
        #endif
    }

    /// One more cache base made, or one served.
    @inline(__always) static func base(made: Bool) {
        #if DEBUG
        if made { bases.withLock { $0 += 1 } } else { hits.withLock { $0 += 1 } }
        #endif
    }

    /// `count` more layers laid onto a region.
    @inline(__always) static func layers(_ count: Int) {
        #if DEBUG
        layerComposites.withLock { $0 += count }
        #endif
    }
}
