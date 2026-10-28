// PhotoRenderCount.swift: debug-only counts of the render work Photo does, for the idle-work and budget
// tests (AppSnapshotTests' IdleWorkTests). `regions` is every region a canvas route composites (a CPU tile,
// a GPU band) and `layerComposites` every layer laid onto one; `rows` and `rowLayers` are the same for the
// reference path (a Curves histogram row, an export, a snapshot); `bases` and `hits` are the canvas's
// PhotoCompositeCache's; `resamples` counts Free Transform's CPU resamples of the draft layer. The histogram composites its rows through the canvas routes' seam with a cache of its
// own, so it counts inside `asRows`, where a region, a layer and a cache lookup land on the reference path's
// counters: a test tells a drag's work from a recount's. The counters are process-wide, so a suite that reads
// them nests in BodyCountSuites like the body counters. A test that drives the renderer itself reads a `Tally`
// instead: bound with `$tally.withValue` around its renders, it counts only the work done in that task and its
// child tasks, so suites running alongside never move it. In release the calls compile to nothing. Linux-safe.
import Synchronization

public enum PhotoRenderCount {
    #if DEBUG
    public static let regions = Mutex(0)
    public static let layerComposites = Mutex(0)
    /// Regions the reference path composited (histogram rows, export, snapshots) and the layers laid onto them,
    /// apart from the canvas routes' so a test can tell a drag's work from a recount's.
    public static let rows = Mutex(0), rowLayers = Mutex(0)
    /// The canvas's PhotoCompositeCache bases made, and regions served from a kept base.
    public static let bases = Mutex(0), hits = Mutex(0)
    /// Free Transform's CPU resamples of the draft's layer: an exact frame or commit (`draftPlaced`), or a drag
    /// frame's draw through the matrix (`compositeDraft`). A drag the compositor moves makes none.
    public static let resamples = Mutex(0)
    /// True inside `asRows`.
    @TaskLocal static var countingRows = false

    /// One test's counts, under the same names IdleWorkTests reads: "regions", "layers", "bases", "hits", "rows",
    /// "rowLayers".
    public final class Tally: Sendable {
        private let counts = Mutex<[String: Int]>([:])
        public init() {}
        public var snapshot: [String: Int] { counts.withLock { $0 } }
        func add(_ name: String, _ count: Int = 1) { counts.withLock { $0[name, default: 0] += count } }
    }

    /// The tally the current task's renders also count into; nil outside a `$tally.withValue`.
    @TaskLocal public static var tally: Tally?
    #endif

    /// Runs `body` with the canvas routes' counts taken as the reference path's: a region composited is the row
    /// the caller counted with `row()`, a layer laid on it is a row layer, and a cache's base or hit is not the
    /// canvas's. The Curves histogram counts its rows in here.
    static func asRows<T>(_ body: () throws -> T) rethrows -> T {
        #if DEBUG
        try $countingRows.withValue(true, operation: body)
        #else
        try body()
        #endif
    }

    /// One more region composited.
    @inline(__always) static func region() {
        #if DEBUG
        guard !countingRows else { return }
        regions.withLock { $0 += 1 }
        tally?.add("regions")
        #endif
    }

    /// One more region through the reference path.
    @inline(__always) static func row() {
        #if DEBUG
        rows.withLock { $0 += 1 }
        tally?.add("rows")
        #endif
    }

    /// `count` more layers laid onto a reference-path region.
    @inline(__always) static func rowLayers(_ count: Int) {
        #if DEBUG
        rowLayers.withLock { $0 += count }
        tally?.add("rowLayers", count)
        #endif
    }

    /// One more cache base made, or one served.
    @inline(__always) static func base(made: Bool) {
        #if DEBUG
        guard !countingRows else { return }
        if made { bases.withLock { $0 += 1 } } else { hits.withLock { $0 += 1 } }
        tally?.add(made ? "bases" : "hits")
        #endif
    }

    /// One more CPU resample of Free Transform's draft layer.
    @inline(__always) static func resample() {
        #if DEBUG
        resamples.withLock { $0 += 1 }
        #endif
    }

    /// `count` more layers laid onto a region.
    @inline(__always) static func layers(_ count: Int) {
        #if DEBUG
        if countingRows {
            rowLayers.withLock { $0 += count }
            tally?.add("rowLayers", count)
        } else {
            layerComposites.withLock { $0 += count }
            tally?.add("layers", count)
        }
        #endif
    }
}
