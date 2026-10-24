// LibraryActions.swift: the actions Library's menus and keys run on the
// catalog (adopt-command-catalog AC-l1). Each was a closure in a
// `LibraryWindow+<Area>.swift` file; it is now one `LibraryAction` case,
// `help(_:)` says why it can't run (the menu's reason, the services' own
// reason first where the menu reads one), and `run(_:)` does what the
// closure did or throws that reason and changes nothing. A cull the
// services refuse sets `cullError` as before and throws it too (on sample
// data it ends with the import hint). Import Folder… (an open panel),
// Show Catalog in Finder and the thumbnail hooks stay in the view: they
// touch files or the window, not the catalog. The loupe's zoom steps its own
// stop table (`loupeZoomSteps`) on the suite's zoom model (SuiteKernel's
// ZoomSteps and ZoomLevel, which `LoupeZoom` names). Linux-safe.
import struct SuiteKernel.ZoomSteps

/// One menu or key action on the catalog.
public enum LibraryAction: Hashable, Sendable {
    case undo, redo, selectAll, deselect, loadSamples, dismissImportNotice
    /// A single key's change (0–5, P, X, U); Auto Advance may move the loupe on.
    case cull(CullChange)
    case setRating(Int), setFlag(PhotoFlag), setLabel(PhotoLabel?)
    case toggleAutoAdvance, dismissCullError
    case showGrid, showLoupe, setSort(LibrarySort), showFirst, showLast
    /// Larger Thumbnails in the grid, a zoom step against the measured fit in the loupe.
    case zoomIn(fitScale: Double), zoomOut(fitScale: Double)
    case zoomToFit, actualSize
    /// The grid toolbar's size slider: the thumbnail size in points.
    case setCellSize(Int)
    /// The canvas's pinch: the fit scale itself is Zoom to Fit.
    case zoomTo(Double, fitScale: Double)
}

/// Why an action didn't run: the reason a disabled item shows, or the services' refusal.
public struct LibraryRefusal: Error, Hashable, Sendable {
    public let reason: String
    public init(_ reason: String) { self.reason = reason }
}

extension LibraryCatalog {
    /// The cull rule's reason for a rating outside 0...5.
    public static let ratingRangeReason = "A rating is 0 to 5 stars."
    static let openLoupeToZoom = "Open a photo in the loupe to zoom."

    /// Why `action` can't run now; nil when it can.
    public func help(_ action: LibraryAction) -> String? {
        switch action {
        case .undo: undoTitle == nil ? "There is nothing to undo." : nil
        case .redo: redoTitle == nil ? "There is nothing to redo." : nil
        case .selectAll: order.isEmpty ? "There are no photos to select." : nil
        case .deselect: selection.isEmpty ? "No photos are selected." : nil
        case .loadSamples: canLoadSamples ? nil : LibraryError.newerCatalog(version: 0).message
        case .dismissImportNotice: importNotice == nil ? "There is no import notice to close." : nil
        case .setRating(let stars) where !(0...5).contains(stars): Self.ratingRangeReason
        case .cull, .setRating, .setFlag, .setLabel:
            cullTargets.isEmpty ? reason("culling", "Select photos first.") : nil
        case .toggleAutoAdvance, .dismissCullError, .setCellSize: nil
        case .showGrid: mode == .loupe ? nil : "The grid is already showing."
        case .showLoupe:
            mode == .grid && !isSelectedCollectionEmpty ? nil : "The loupe is already showing, or there are no photos."
        case .setSort: order.isEmpty ? "There are no photos to sort." : nil
        case .showFirst: inLoupe && canShowPreviousInLoupe ? nil : "The loupe is already on the first photo."
        case .showLast: inLoupe && canShowNextInLoupe ? nil : "The loupe is already on the last photo."
        case .zoomIn(let fit): zoomHelp(step: 1, fitScale: fit)
        case .zoomOut(let fit): zoomHelp(step: -1, fitScale: fit)
        case .zoomToFit:
            mode == .grid ? Self.openLoupeToZoom
                : inLoupe && loupeZoom != .fit ? nil : reason("loupe", "The photo already fits.")
        case .actualSize:
            mode == .grid ? Self.openLoupeToZoom
                : inLoupe && loupeZoom != .actual ? nil : reason("loupe", "The photo is already at actual size.")
        case .zoomTo: inLoupe ? nil : Self.openLoupeToZoom
        }
    }

    /// Runs `action` as its menu item or key did, or throws `help(action)` and changes nothing.
    public mutating func run(_ action: LibraryAction) throws(LibraryRefusal) {
        if let why = help(action) { throw LibraryRefusal(why) }
        switch action {
        case .undo: undo()
        case .redo: redo()
        case .selectAll: selectAll()
        case .deselect: select([])
        case .loadSamples: loadSamples()
        case .dismissImportNotice: dismissImportNotice()
        case .cull(let change): try culled { $0.cull(change) }
        case .setRating(let stars): try culled { $0.setRating(stars) }
        case .setFlag(let flag): try culled { $0.setFlag(flag) }
        case .setLabel(let label): try culled { $0.setLabel(label) }
        case .toggleAutoAdvance: setAutoAdvance(!autoAdvance)
        case .dismissCullError: dismissCullError()
        case .showGrid: showGrid()
        case .showLoupe: showLoupe()
        case .setSort(let sort): setSort(sort)
        case .showFirst: showFirstInLoupe()
        case .showLast: showLastInLoupe()
        case .zoomIn(let fit): mode == .grid ? stepCellSize(by: 1) : stepZoom(by: 1, fitScale: fit)
        case .zoomOut(let fit): mode == .grid ? stepCellSize(by: -1) : stepZoom(by: -1, fitScale: fit)
        case .zoomToFit: zoomLoupe(.fit)
        case .setCellSize(let size): setCellSize(size)
        case .actualSize: zoomLoupe(.actual)
        case .zoomTo(let scale, let fit): zoomLoupe(abs(scale - fit) < 0.0001 ? .fit : .scale(scale))
        }
    }

    /// A cull through the services; their refusal (already in `cullError`) is thrown as well.
    private mutating func culled(_ change: (inout LibraryCatalog) -> Void) throws(LibraryRefusal) {
        change(&self)
        if let refused = cullError { throw LibraryRefusal(refused) }
    }

    /// The loupe is open on a photo it shows.
    private var inLoupe: Bool { mode == .loupe && loupeItem != nil }

    /// The services member's reason, else `fallback`: what the menu's item says.
    private func reason(_ member: String, _ fallback: String) -> String {
        services.unavailable[member] ?? fallback
    }

    /// Zoom In (`step` 1) or Zoom Out (-1): the thumbnail size in the grid, the zoom steps in the loupe.
    private func zoomHelp(step: Int, fitScale: Double) -> String? {
        let limit = step > 0 ? "Can't zoom in further." : "Can't zoom out further."
        if mode == .grid {
            return (step > 0 ? canShowLargerThumbnails : canShowSmallerThumbnails) ? nil : limit
        }
        return inLoupe && loupeStep(step, fitScale: fitScale) != nil ? nil : reason("loupe", limit)
    }
}

extension LibraryCatalog {
    /// The loupe's Zoom In and Zoom Out stops, 12.5% to 800%, on the suite's zoom model.
    public static let loupeZoomSteps = ZoomSteps(stops: [0.125, 0.25, 0.5, 1, 2, 4, 8])

    /// Sets the loupe's zoom; a scale of 1 is `.actual`, and a scale that
    /// isn't a positive finite number changes nothing.
    public mutating func zoomLoupe(_ zoom: LoupeZoom) {
        if case .scale(let scale) = zoom {
            guard LoupeZoom.isUsable(scale) else { return }
            loupeZoom = LoupeZoom(scale: scale)
        } else {
            loupeZoom = zoom
        }
    }

    /// The next step above (positive) or below the current scale; fit counts
    /// as its scale. Moves `steps` steps, staying put past either end.
    public mutating func stepZoom(by steps: Int, fitScale: Double) {
        for _ in 0..<min(steps.magnitude, UInt(Self.loupeZoomSteps.stops.count)) {
            guard let target = loupeStep(steps, fitScale: fitScale) else { return }
            loupeZoom = LoupeZoom(scale: target)
        }
    }

    /// The scale one step up (`step` positive) or down from the loupe's, or nil past that end.
    private func loupeStep(_ step: Int, fitScale: Double) -> Double? {
        let current = loupeZoom.scale(fit: fitScale), table = Self.loupeZoomSteps
        let target = step > 0 ? table.zoomedIn(from: current) : table.zoomedOut(from: current)
        return (step > 0 ? target > current : target < current) ? target : nil
    }

    /// "Larger Thumbnails" in the grid, "Zoom In" in the loupe.
    public var zoomInTitle: String {
        mode == .grid ? "Larger Thumbnails" : "Zoom In"
    }

    /// "Smaller Thumbnails" in the grid, "Zoom Out" in the loupe.
    public var zoomOutTitle: String {
        mode == .grid ? "Smaller Thumbnails" : "Zoom Out"
    }
}

extension LibraryCatalog {
    /// The sizes the grid's Size bar offers, in points, in `cellSizeStep` steps.
    public static let cellSizeRange = 80...320

    /// The Size bar: `size` snapped to the nearest step from 80, clamped to `cellSizeRange`.
    public mutating func setCellSize(_ size: Int) {
        let range = Self.cellSizeRange, clamped = min(max(size, range.lowerBound), range.upperBound)
        let steps = (Double(clamped - range.lowerBound) / Double(Self.cellSizeStep)).rounded()
        cellSize = range.lowerBound + Int(steps) * Self.cellSizeStep
    }
}
