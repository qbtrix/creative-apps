// LibraryCommandCatalog.swift (adopt-command-catalog AC-l2): Library's menu actions as SuiteKernel command specs
// over LibraryCatalog, so a menu, the afterglow CLI and an agent run one path. Each spec's availability is the
// reason the menu shows today and its run is today's method: AC-l1's `help(_:)` and `run(_:)` for the actions
// they cover, the develop and crop methods with the window's enablement and the menu's reason for the Photo menu.
// Import Folder… and Export… stay out: they need a folder panel and the async importer and export runner.
// Ids are `<menu>.<action>` in lowercase; Tests/command-ids/library.txt keeps them. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// The catalog's undo history as the kernel reads it.
struct LibraryCatalogSteps: HistoryReading {
    let catalog: LibraryCatalog
    var canUndo: Bool { catalog.history.top != nil }
    var canRedo: Bool { catalog.history.redoTop != nil }
    var undoName: String? { catalog.history.top?.name }
    var redoName: String? { catalog.history.redoTop?.name }
    var isDirty: Bool { catalog.catalogSession.isDirty }
}

extension LibraryCatalog {
    struct NoParams: Codable, Sendable {}
    /// edit.select's ids; view.zoom-in's and zoom-out's measured fit; view.sort's order; the rating and the label.
    struct SelectParams: Codable, Sendable { var ids: [String] }
    struct ZoomParams: Codable, Sendable { var fitScale: Double? }
    struct SortParams: Codable, Sendable { var sort: String }
    struct RatingParams: Codable, Sendable { var stars: Int }
    struct LabelParams: Codable, Sendable { var label: String? }

    /// Every Library menu action as a command spec, in menu order.
    public static let commands: [CommandSpec<LibraryCatalog>] = fileAndEditSpecs + viewSpecs + photoSpecs + metadataSpecs
        + FileFlowCommands.specs(LibraryCatalog.self)
        + folderSpecs

    /// The specs as a catalog whose history is the catalog's own.
    public static let catalog: CommandCatalog<LibraryCatalog> =
        (try? CommandCatalog(app: "library", commands, history: { LibraryCatalogSteps(catalog: $0) })) ?? .empty(app: "library")

    /// `help` as an availability: nil is available, a reason is unavailable with it.
    static func available(_ help: String?) -> Availability { help.map(Availability.unavailable) ?? .available }

    /// A spec with params `P` run as `action(catalog, params)` through `run(_:)`; available when `help(probe)` is nil.
    static func action<P: Codable & Sendable>(
        _ id: String, _ title: String, _ summary: String, _ kind: CommandKind, _ params: P.Type, probe: LibraryAction,
        schema: ParamSchema = ParamSchema.none, example: JSONValue = .object([:]),
        _ action: @escaping @Sendable (LibraryCatalog, P) -> LibraryAction
    ) -> CommandSpec<LibraryCatalog> {
        .typed(id, title: title, summary: summary, kind: kind, params: P.self, schema: schema, example: example,
               availability: { available($0.help(probe)) }) { c, p in try c.run(action(c, p)); return JSONValue.object([:]) }
    }

    /// A no-params action.
    static func plain(_ id: String, _ title: String, _ summary: String, _ kind: CommandKind, _ a: LibraryAction) -> CommandSpec<LibraryCatalog> {
        action(id, title, summary, kind, NoParams.self, probe: a) { _, _ in a }
    }

    /// Pick, Reject and Clear Flag: each sets its flag, so a second Pick changes nothing.
    static func flag(_ id: String, _ title: String, _ summary: String, _ flag: PhotoFlag) -> CommandSpec<LibraryCatalog> {
        action(id, title, summary, .edit, NoParams.self, probe: .setFlag(flag)) { _, _ in .setFlag(flag) }
    }

    /// A Photo menu item: enabled by `on`, else the services' `member` reason or the menu's `fallback`.
    static func photo(
        _ id: String, _ title: String, _ summary: String, _ kind: CommandKind, _ member: String, _ fallback: String,
        on: @escaping @Sendable (LibraryCatalog) -> Bool, run: @escaping @Sendable (inout LibraryCatalog) -> Void
    ) -> CommandSpec<LibraryCatalog> {
        .typed(id, title: title, summary: summary, kind: kind, params: NoParams.self, schema: ParamSchema.none, example: .object([:]),
               availability: { c in on(c) ? .available : .unavailable(c.services.unavailable[member] ?? fallback) }
        ) { c, _ in run(&c); return JSONValue.object([:]) }
    }

    static let fileAndEditSpecs: [CommandSpec<LibraryCatalog>] = [
        plain("file.load-samples", "Load Sample Photos", "Replaces the photos with the 60 sample photos.", .file, .loadSamples),
        plain("edit.undo", "Undo", "Puts back the last edit.", .view, .undo),
        plain("edit.redo", "Redo", "Makes the last undone edit again.", .view, .redo),
        .typed("edit.select", title: "Select", summary: "Selects the shown photos with these ids.", kind: .view,
               params: SelectParams.self, schema: .object(["ids": .array(of: .string("A photo's id."))], required: ["ids"]),
               example: .object(["ids": .array([.string("IMG_0001")])]), availability: { available($0.help(.selectAll)) }
        ) { c, p in c.select(Set(p.ids)); return JSONValue.object([:]) },
        plain("edit.select-all", "Select All", "Selects every shown photo.", .view, .selectAll),
        plain("edit.deselect", "Deselect", "Clears the selection.", .view, .deselect),
    ]

    static let zoomSchema = ParamSchema.object(["fitScale": .optional(.number("The loupe's measured fit scale; 1 when left out.", minimum: 0))], required: [])

    static let viewSpecs: [CommandSpec<LibraryCatalog>] = [
        plain("view.grid", "Grid", "Shows the grid.", .view, .showGrid),
        plain("view.loupe", "Loupe", "Opens the first selected photo, else the last or first one, in the loupe.", .view, .showLoupe),
        action("view.zoom-in", "Zoom In", "Larger thumbnails in the grid; the next zoom step in the loupe.", .view, ZoomParams.self,
               probe: .zoomIn(fitScale: 1), schema: zoomSchema) { .zoomIn(fitScale: $1.fitScale ?? 1) },
        action("view.zoom-out", "Zoom Out", "Smaller thumbnails in the grid; the previous zoom step in the loupe.", .view, ZoomParams.self,
               probe: .zoomOut(fitScale: 1), schema: zoomSchema) { .zoomOut(fitScale: $1.fitScale ?? 1) },
        plain("view.zoom-to-fit", "Zoom to Fit", "Fits the loupe's photo in the window.", .view, .zoomToFit),
        plain("view.actual-size", "Actual Size", "Shows the loupe's photo at 100%.", .view, .actualSize),
        action("view.sort", "Sort By", "Orders the photos by capture date, name or rating.", .view, SortParams.self, probe: .setSort(.name),
               schema: .object(["sort": .string("The order.", oneOf: LibrarySort.allCases.map(\.rawValue))], required: ["sort"]),
               example: .object(["sort": .string("Name")])) { .setSort(LibrarySort(rawValue: $1.sort) ?? .captureDate) },
    ]

    static let photoSpecs: [CommandSpec<LibraryCatalog>] = [
        photo("photo.copy-settings", "Copy Settings", "Copies the one target photo's develop settings.", .view,
              "develop", "Develop isn't connected yet.", on: { $0.canCopySettings }, run: { $0.copySettings() }),
        photo("photo.paste-settings", "Paste Settings", "Pastes the copied adjustments onto every target, keeping each crop.", .edit,
              "develop", "Develop isn't connected yet.", on: { $0.canPasteSettings }, run: { $0.pasteSettings() }),
        photo("photo.reset-develop", "Reset Develop", "Sets every adjustment of the targets back to neutral, not the crop.", .edit,
              "develop", "Develop isn't connected yet.", on: { $0.canEditDevelop }, run: { $0.resetDevelop(nil) }),
        photo("photo.crop", "Crop", "Opens a crop draft on the loupe's photo, or applies the open draft as one step.", .edit,
              "crop", "Crop isn't connected yet.", on: { $0.cropHelp == nil }, run: { $0.toggleCrop() }),
        photo("photo.reset-crop", "Reset Crop", "Clears the loupe photo's crop, or puts the open draft back to Original.", .edit,
              "crop", "Crop isn't connected yet.", on: { $0.resetCropHelp == nil }, run: { $0.resetCrop() }),
    ]

    static let metadataSpecs: [CommandSpec<LibraryCatalog>] = [
        action("metadata.set-rating", "Set Rating", "Rates the loupe's photo, else the selected ones, 0 to 5 stars.", .edit, RatingParams.self, probe: .setRating(3),
               schema: .object(["stars": .integer("Stars, 0 to 5.", minimum: 0, maximum: 5)], required: ["stars"]),
               example: .object(["stars": .number(3)])) { .setRating($1.stars) },
        flag("metadata.pick", "Pick", "Flags the targets as picks.", .pick),
        flag("metadata.reject", "Reject", "Flags the targets as rejects.", .reject),
        flag("metadata.clear-flag", "Clear Flag", "Clears the targets' flag.", .none),
        action("metadata.set-label", "Set Label", "Sets the targets' color label; no label clears it.", .edit, LabelParams.self, probe: .setLabel(.red),
               schema: .object(["label": .optional(.string("The color.", oneOf: PhotoLabel.allCases.map(\.rawValue)))], required: []),
               example: .object(["label": .string("Red")])) { .setLabel($1.label.flatMap(PhotoLabel.init(rawValue:))) },
        plain("metadata.auto-advance", "Auto Advance", "Turns moving the loupe on after a rating or a flag on or off.", .view, .toggleAutoAdvance),
    ]
}

/// File > Share… as its menu item reads it: why it can't act now, nil when it can.
public struct LibraryShareMenu: Sendable, Equatable {
    public var help: String?
    public init(help: String?) { self.help = help }
}

extension LibraryCatalog {
    /// File > Share… (`file.share`): the window opens the system's share menu for the selection, so the spec stays
    /// out of `commands` (and the ledger) like Import Folder… and Export…; it is available while the menu's help is nil.
    public static let shareMenuSpec: CommandSpec<LibraryShareMenu> =
        .typed("file.share", title: "Share…", summary: "Shares the selected photos, location off.", kind: .file,
               params: NoParams.self, schema: ParamSchema.none, example: .object([:]), availability: { available($0.help) }
        ) { _, _ -> JSONValue in throw CatalogError.notBuilt(id: "file.share", feature: "SH-5") }
}
