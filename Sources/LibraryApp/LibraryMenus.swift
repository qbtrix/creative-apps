// LibraryMenus.swift: LibraryMenu, what the menu bar (LibraryCommands) and
// the window's keys read from and call on the focused Library window. One
// sub-struct per area (edit, file, thumbnails, cull, persist, view, photo,
// export), each filled by that area's own `LibraryWindow+<Area>.swift`.
// Every member is optional: a nil action disables its menu item (or ignores
// its key), and `help(for:)` gives the services' reason as its help.
import LibraryModel
import SwiftUI

/// What the menu bar reads from and calls on the focused window.
struct LibraryMenu {
    typealias Action = @MainActor () -> Void

    /// Edit (spine): Undo, Redo, Select All, Deselect; File's Load Sample Photos.
    struct Edit {
        var undo: Action?
        var redo: Action?
        var undoTitle: String = "Undo"
        var redoTitle: String = "Redo"
        var selectAll: Action?
        var deselect: Action?
        var loadSamples: Action?
    }

    /// File (import): Import Folder…, a folder dropped on the empty catalog, and the import notice's actions.
    struct File {
        var importFolder: Action?
        var importDropped: (@MainActor (String) -> Void)?
        var importHelp: String?  // why Import Folder… can't act, before the services' reason
        var showImportFailures: Action?
        var dismissImportNotice: Action?
    }

    /// The grid's thumbnails (thumbnails): what the grid shows and at what size.
    struct Thumbnails {
        var visibleChanged: (@MainActor ([String]) -> Void)?
        var cellSizeChanged: (@MainActor (_ size: Int, _ scale: Int) -> Void)?
    }

    /// Metadata (cull): rating, flag, label, Auto Advance and the single keys.
    struct Cull {
        var key: (@MainActor (LibraryKey) -> Void)?
        var setRating: (@MainActor (Int) -> Void)?
        var setFlag: (@MainActor (PhotoFlag) -> Void)?
        var setLabel: (@MainActor (PhotoLabel?) -> Void)?
        var toggleAutoAdvance: Action?
        var autoAdvance: Bool = false
        var dismissCullError: Action?
    }

    /// The catalog file (persist).
    struct Persist {
        var showCatalogInFinder: Action?
        /// Closes the notice of a damaged catalog opened from a backup (catalog-backup BK-5).
        var dismissBackupNotice: Action?
    }

    /// View (loupe-viewport): modes, zoom, sort, first and last photo.
    struct Viewing {
        var grid: Action?
        var loupe: Action?
        var zoomIn: Action?
        var zoomOut: Action?
        var zoomToFit: Action?
        var actualSize: Action?
        var setSort: (@MainActor (LibrarySort) -> Void)?
        var sort: LibrarySort = .captureDate
        var setCellSize: (@MainActor (Int) -> Void)?  // the grid toolbar's Size bar
        var first: Action?
        var last: Action?
        var zoomInTitle: String = "Zoom In"
        var zoomOutTitle: String = "Zoom Out"
        var zoomTo: (@MainActor (Double) -> Void)?  // the canvas's pinch and its own zoom keys
        var fitMeasured: (@MainActor (Double) -> Void)?  // the fit scale the loupe view measured
    }

    /// The Develop tab's actions (develop): no menu items of their own; the
    /// tab's rows, curve, levels, resets, Sync and Show Original call them.
    struct Develop {
        var set: (@MainActor (DevelopSlider, Double) -> Void)?
        var setCurve: (@MainActor ([DevelopCurvePoint]) -> Void)?
        var setLevels: (@MainActor (DevelopLevels.Field, Double) -> Void)?
        var endEdit: Action?  // a row's or the curve's onEnd
        var reset: (@MainActor (DevelopGroup?) -> Void)?
        var resetSlider: (@MainActor (DevelopSlider) -> Void)?
        var resetCurve: Action?
        var resetLevels: Action?
        var sync: Action?
        var syncTitle: String?
        var toggleOriginal: Action?
        var showsOriginal = false
    }

    /// Photo: the develop half (develop) and the crop half (crop).
    struct Photo {
        var copySettings: Action?
        var pasteSettings: Action?
        var resetDevelop: Action?
        var develop = Develop()
        var toggleCrop: Action?
        var cropTitle: String = "Crop"
        var applyCrop: Action?
        var resetCrop: Action?
        /// image.rotate-ccw, image.rotate-cw and image.flip on the selection (orientation-crop OC-9).
        var rotateLeft, rotateRight, flipHorizontal, flipVertical: Action?
    }

    /// File > Export… (export).
    struct Export {
        var export: Action?
        var exportHelp: String?  // why Export… can't act, before the services' reason
    }

    /// Photo > Delete Rejected Photos… (cull-finish, LibraryWindow+Trash.swift): the Model's
    /// title, and the action that opens the confirm, nil while `help` says why it can't run.
    struct Trash {
        var deleteRejects: Action?
        var title: String = "Delete Rejected Photos…"
        var help: String?
    }

    var edit = Edit()
    var file = File()
    var thumbnails = Thumbnails()
    var cull = Cull()
    var persist = Persist()
    var view = Viewing()
    var photo = Photo()
    var export = Export()
    var share = Share()
    /// The services' reasons by member ("importer", "loupe", ...): `LibraryCatalog.help(for:)`.
    var reasons: [String: String] = [:]

    /// Every item disabled: no window, or a view drawn outside one (snapshots).
    @MainActor static let disabled = LibraryMenu()

    /// Why the services member `member` can't act yet; nil once it is live.
    func help(for member: String) -> String? { reasons[member] }
}

extension FocusedValues {
    @Entry var libraryMenu: LibraryMenu?
    /// Published by the trash area, which owns the confirm's presented flag.
    @Entry var libraryTrash: LibraryMenu.Trash?
}
