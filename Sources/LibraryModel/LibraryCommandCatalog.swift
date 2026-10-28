// LibraryCommandCatalog.swift (adopt-command-catalog AC-l2): Library's menu actions as SuiteKernel command specs
// over LibraryCatalog, so a menu, the afterglow CLI and an agent run one path. Each spec's availability is the
// reason the menu shows today and its run is today's method: AC-l1's `help(_:)` and `run(_:)` for the actions
// they cover, the develop and crop methods with the window's enablement and the menu's reason for the Photo menu.
// Import Folder… and Export… (CS-3) take the panel's folder as a param and begin the run; the window's panel and the
// async importer and export runner do the rest. Show Original (CS-3) is state the loupe's render reads.
// CS-5: the export sheet's controls (`export.*`), the notice row's (`notice.*`, `file.show-catalog`) and Develop's
// per-slider resets (`photo.reset-<slider>`) and `photo.set-develop` as specs too; the window still opens panels and reveals files.
// The grid toolbar's controls (#3632) are view.thumbnail-size, view.sort, file.import-folder and file.export.
// Ids are `<menu>.<action>` in lowercase; Tests/command-ids/library.txt keeps them. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteImaging
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
    struct SizeParams: Codable, Sendable { var size: Int }
    /// A folder param, such as the one the export sheet writes to.
    struct FolderParams: Codable, Sendable { var folder: String }

    /// True while the loupe's photo shows without its adjustments; stepping to another photo or the grid ends it.
    public var showsOriginal: Bool { mode == .loupe && originalPhotoID != nil && originalPhotoID == focusedItemID }

    /// Show Original on for the loupe's photo, or off; the develop values and the history stay as they are.
    public mutating func toggleShowOriginal() {
        originalPhotoID = showsOriginal ? nil : focusedItemID
    }

    /// Why Show Original can't act: the develop service's reason, the develop help, else the loupe's.
    var showOriginalHelp: String? {
        if let reason = services.unavailable["develop"] { return reason }
        if let help = developHelp { return help }
        return canShowOriginal ? nil : "Open a photo in the loupe to see its original."
    }

    /// Why Import Folder… can't act: an import running, the importer's reason, or the catalog still loading.
    var importFolderHelp: String? {
        importHelp ?? (catalogState == .loading ? "The library is still loading." : nil)
    }

    /// Every Library menu action as a command spec, in menu order.
    public static let commands: [CommandSpec<LibraryCatalog>] = fileAndEditSpecs + viewSpecs + photoSpecs + metadataSpecs
        + FileFlowCommands.specs(LibraryCatalog.self)
        + folderSpecs + exportSheetSpecs + noticeSpecs + resetSliderSpecs + [setDevelopSpec, sharePrepareSpec, copySpec, thumbnailStatsSpec] + backupSpecs
        + LibraryCropDocument.specs + AdjustCommands.specs(LibraryCatalog.self)

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

    /// Export…'s options: the sheet's fields, each optional but the folder.
    static let exportSchema = ParamSchema.object([
        "folder": .string("The folder the photos are written to."),
        "longEdge": .optional(.integer("The long edge in pixels; left out writes the original size.", minimum: 16, maximum: 16384)),
        "quality": .optional(.integer("JPEG and HEIC quality, 0 to 100.", minimum: 0, maximum: 100)),
        "format": .optional(.string("The file format.", oneOf: ExportFormat.allCases.map(\.rawValue))),
        "naming": .optional(.object(["template": .string("The file name template, such as {name}.")], required: ["template"])),
        "sidecar": .optional(.boolean),
        "metadata": .optional(.string("What the files keep of the metadata.", oneOf: ExportMetadata.allCases.map(\.rawValue))),
    ], required: ["folder"])

    static let fileAndEditSpecs: [CommandSpec<LibraryCatalog>] = [
        .typed("file.import-folder", title: "Import Folder…", summary: "Begins importing the photos in a folder.", kind: .file,
               params: ImportOptions.self, schema: importSchema,
               example: .object(["folder": .string("/tmp/Shoot")]), availability: { available($0.importFolderHelp) }
        ) { c, p in
            guard c.beginImport() != nil else { throw CatalogError.unavailable(id: "file.import-folder", why: c.importFolderHelp ?? "") }
            c.importCopy = p.copy
            return JSONValue.object(["folder": .string(p.folder)])
        },
        plain("file.load-samples", "Load Sample Photos", "Replaces the photos with the 60 sample photos.", .file, .loadSamples),
        .typed("file.export", title: "Export…", summary: "Opens the export sheet on the targets with these options.", kind: .file,
               params: ExportOptions.self, schema: exportSchema, example: .object(["folder": .string("/tmp/Exports")]),
               availability: { available($0.exportHelp) }
        ) { c, o in
            guard c.beginExport(folder: o.folder, last: o) else { throw CatalogError.unavailable(id: "file.export", why: c.exportHelp ?? "") }
            return JSONValue.object(["folder": .string(o.folder)])
        },
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
        .typed("view.show-original", title: "Show Original", summary: "Shows the loupe's photo without its adjustments, or with them again.",
               kind: .view, params: NoParams.self, schema: ParamSchema.none, example: .object([:]),
               availability: { available($0.showOriginalHelp) }
        ) { c, _ in c.toggleShowOriginal(); return JSONValue.object(["on": .bool(c.showsOriginal)]) },
        action("view.thumbnail-size", "Thumbnail Size", "Sets the grid's thumbnail size, 80 to 320 points in steps of 40.", .view,
               SizeParams.self, probe: .setCellSize(160),
               schema: .object(["size": .integer("Points, 80 to 320.", minimum: 80, maximum: 320)], required: ["size"]),
               example: .object(["size": .number(200)])) { .setCellSize($1.size) },
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

extension LibraryCatalog {
    struct NameParams: Codable, Sendable { var name: String }
    /// A preset to apply: a built-in by its name alone, or a saved one with every field (`quality` given).
    struct PresetParams: Codable, Sendable {
        var name: String, longEdge: Int?, quality: Int?, format: ExportFormat?, naming: ExportNaming?, sidecar: Bool?
    }

    /// Why the sheet's options can't change: only while editing them.
    var exportEditingHelp: String? {
        switch exportState {
        case .editing: nil
        case .running: "The export is running."
        case .idle, .finished: "Choose File > Export… to open the export sheet."
        }
    }

    /// Why Close (Cancel or Done) can't act: the sheet is closed, or the export runs.
    var exportCloseHelp: String? {
        switch exportState {
        case .idle: "The export sheet isn't open."
        case .running: "The export is still running."
        case .editing, .finished: nil
        }
    }

    /// The finished run's summary, nil before one ends.
    var exportFinished: ExportSummary? { if case .finished(let summary) = exportState { summary } else { nil } }

    /// A spec that can run while `help` is nil, `run` refusing with that reason otherwise.
    static func sheet<P: Codable & Sendable>(
        _ id: String, _ title: String, _ summary: String, _ kind: CommandKind, _ params: P.Type,
        schema: ParamSchema = ParamSchema.none, example: JSONValue = .object([:]), help: @escaping @Sendable (LibraryCatalog) -> String?,
        _ run: @escaping @Sendable (inout LibraryCatalog, P) throws -> JSONValue
    ) -> CommandSpec<LibraryCatalog> {
        .typed(id, title: title, summary: summary, kind: kind, params: P.self, schema: schema, example: example,
               availability: { available(help($0)) }) { c, p in
            if let why = help(c) { throw CatalogError.unavailable(id: id, why: why) }
            return try run(&c, p)
        }
    }

    static let presetSchema = ParamSchema.object([
        "name": .string("A built-in preset's name, or a saved one's with its fields."),
        "longEdge": .optional(.integer("The long edge in pixels; left out with quality writes the original size.", minimum: 16, maximum: 16384)),
        "quality": .optional(.integer("JPEG and HEIC quality, 0 to 100; given, the fields are the whole preset.", minimum: 0, maximum: 100)),
        "format": .optional(.string("The file format.", oneOf: ExportFormat.allCases.map(\.rawValue))),
        "naming": .optional(.object(["template": .string("The file name template, such as {name}.")], required: ["template"])),
        "sidecar": .optional(.boolean),
    ], required: ["name"])

    /// The export sheet's controls: Choose…, a preset, Save as Preset, Cancel while running, Try Again, Show in
    /// Finder, and Cancel or Done (Close). Its Export runs `file.export` with the sheet's options.
    static let exportSheetSpecs: [CommandSpec<LibraryCatalog>] = [
        sheet("export.set-folder", "Choose Export Folder", "Sets the folder the open export sheet writes to.", .view, FolderParams.self,
              schema: .object(["folder": .string("The folder to write to.")], required: ["folder"]),
              example: .object(["folder": .string("/tmp/Exports")]), help: { $0.exportEditingHelp }) { c, p in
            guard var options = c.exportRun.options else { return .object([:]) }
            options.folder = p.folder
            c.setExportOptions(options)
            return .object(["folder": .string(p.folder)])
        },
        sheet("export.apply-preset", "Apply Preset", "Sets the open export sheet's options but the folder from a preset.", .view,
              PresetParams.self, schema: presetSchema, example: .object(["name": .string("Small")]),
              help: { $0.exportEditingHelp ?? ExportPresets.unavailable }) { c, p in
            let preset = p.quality.map { quality in
                ExportPreset(name: p.name, options: ExportOptions(longEdge: p.longEdge, quality: quality, folder: "",
                                                                  format: p.format ?? .jpeg, naming: p.naming ?? .original, sidecar: p.sidecar ?? false))
            } ?? ExportPresets.builtIns.first { $0.name == p.name }
            guard let preset, let current = c.exportRun.options else {
                throw CatalogError.failed(id: "export.apply-preset", message: "There is no preset named \(p.name).")
            }
            c.setExportOptions(preset.applied(to: current))
            return .object(["name": .string(preset.name)])
        },
        sheet("export.save-preset", "Save as Preset", "Names the open export sheet's options but the folder as a preset.", .file,
              NameParams.self, schema: .object(["name": .string("The preset's name.")], required: ["name"]),
              example: .object(["name": .string("Web")]), help: { $0.exportEditingHelp ?? ExportPresets.unavailable }) { c, p in
            guard !p.name.allSatisfy(\.isWhitespace), let options = c.exportRun.options else {
                throw CatalogError.failed(id: "export.save-preset", message: "Name the preset.")
            }
            return try JSONValue(encoding: ExportPreset(name: p.name, options: options))
        },
        sheet("export.cancel", "Cancel Export", "Stops the running export after the photo it is writing.", .view, NoParams.self,
              help: { c in c.exportState.isRunning ? nil : "No export is running." }) { c, _ in
            _ = c.cancelExport()
            return .object([:])
        },
        sheet("export.retry", "Try Again", "Exports again only the photos that failed, under the same options.", .file, NoParams.self,
              help: { c in c.exportFinished?.failedIDs.isEmpty == false ? nil : "No photos failed to export." }) { c, _ in
            guard let options = c.exportRun.options, let plan = c.retryExport(options: options, existingNames: []) else {
                throw CatalogError.failed(id: "export.retry", message: "No photos failed to export.")
            }
            return .object(["photos": .number(Double(plan.items.count))])
        },
        sheet("export.show-in-finder", "Show in Finder", "Names the finished export's folder and files; the window reveals them.", .file,
              NoParams.self, help: { c in c.exportFinished == nil ? "Nothing has been exported yet." : nil }) { c, _ in
            let written = c.exportFinished?.written ?? []
            return .object(["folder": .string(c.exportRun.options?.folder ?? ""), "files": .array(written.map(JSONValue.string))])
        },
        sheet("export.close", "Close Export", "Closes the export sheet; refused while the export runs.", .view, NoParams.self,
              help: { $0.exportCloseHelp }) { c, _ in
            c.closeExport()
            return .object([:])
        },
    ]

    /// True while the import notice lists the files that couldn't be imported.
    public var showsImportFailures: Bool { importNotice != nil && failuresShownFor == importNotice }

    /// The notice row's controls: its action, Close, and the import notice's Show and Hide.
    static let noticeSpecs: [CommandSpec<LibraryCatalog>] = [
        sheet("file.show-catalog", "Show Catalog in Finder", "Names the damaged catalog file that was set aside; the window reveals it.",
              .file, NoParams.self, help: { $0.catalogState == .damaged ? nil : "The catalog file isn't damaged." }) { _, _ in
            .object(["file": .string("catalog.json.bad")])
        },
        sheet("notice.close", "Close Notice", "Closes the import's notice or a refused cull change's.", .view, NoParams.self,
              help: { c in [.import, .cull].contains(c.notice?.source) ? nil : "There is no notice to close." }) { c, _ in
            if c.notice?.source == .import { c.dismissImportNotice() } else { c.dismissCullError() }
            return .object([:])
        },
        sheet("notice.show-failures", "Show Failures", "Lists the files the last import couldn't read, or hides them again.", .view,
              NoParams.self, help: { c in
                  c.notice?.source == .import && c.importNotice?.failures.isEmpty == false ? nil : "No files failed to import."
              }) { c, _ in
            c.failuresShownFor = c.showsImportFailures ? nil : c.importNotice
            return .object(["on": .bool(c.showsImportFailures)])
        },
    ]

    /// Develop's Reset <slider>: that one slider of the targets back to 0, one step each.
    public static func resetSliderID(_ slider: ToneSlider) -> String { "photo.reset-" + slider.rawValue.lowercased() }
    static let resetSliderSpecs: [CommandSpec<LibraryCatalog>] = ToneSlider.develop.map { slider in
        photo(resetSliderID(slider), "Reset " + slider.title, "Sets the targets' \(slider.title.lowercased()) back to 0.", .edit,
              "develop", "Develop isn't connected yet.", on: { $0.canEditDevelop }, run: { $0.resetDevelop(slider) })
    }

    /// Develop's sliders as a command: one slider of the targets to a value, a drag's token making one step.
    static let setDevelopSpec: CommandSpec<LibraryCatalog> = .typed(
        "photo.set-develop", title: "Set Develop", summary: "Sets one develop slider of the targets, clamped to its range.",
        kind: .edit, params: ToneCommands.SetParams.self,
        schema: .object(["slider": .string("The slider.", oneOf: ToneSlider.develop.map(\.rawValue)),
                         "value": .number("The value, clamped to the slider's range."),
                         "drag": .optional(.string("A drag's token; steps under one token are one undo step.", maxLength: 64))],
                        required: ["slider", "value", "drag"]),
        example: .object(["slider": .string("vibrance"), "value": .number(50)]),
        availability: { available($0.services.unavailable["develop"] ?? $0.developHelp) }
    ) { c, p in
        guard ToneSlider.develop.contains(p.slider) else {
            throw CatalogError.unavailable(id: "photo.set-develop", why: "Develop has no \(p.slider.title) slider.")
        }
        if let why = c.sliderHelp(p.slider) { throw CatalogError.unavailable(id: "photo.set-develop", why: why) }
        c.setDevelop(p.slider, to: p.value, coalesceKey: p.drag)
        return c.developValue(p.slider)?.shared.map { .object([p.slider.rawValue: .number($0)]) } ?? .object([:])
    }
}

extension LibraryNoticeContent.Action {
    /// The command the notice's button runs.
    public var commandID: String {
        switch self {
        case .showCatalogInFinder: "file.show-catalog"
        case .showFailures: "notice.show-failures"
        case .importFolder: "file.import-folder"
        }
    }
}

extension ExportState {
    var isRunning: Bool { if case .running = self { true } else { false } }
}

extension LibraryCatalog {
    /// The disk tier behind the grid's thumbnails (shared-thumbnails ST-6), nil while they are kept in memory only.
    var thumbnailDisk: LiveThumbnailStoreAdapter? { (services.thumbnails as? LiveThumbnails)?.disk }

    /// `thumbnails.stats`: thumbnails decoded and served from disk since the disk tier opened, for a relaunch to read.
    static let thumbnailStatsSpec: CommandSpec<LibraryCatalog> =
        .typed("thumbnails.stats", title: "Thumbnail Stats",
               summary: "Counts the grid thumbnails decoded and the ones read from disk since launch.", kind: .query,
               params: NoParams.self, schema: ParamSchema.none,
               result: .object(["decoded": .integer("Thumbnails decoded.", minimum: 0),
                                "fromDisk": .integer("Thumbnails read from disk.", minimum: 0)], required: ["decoded", "fromDisk"]),
               example: .object([:]),
               availability: { available($0.thumbnailDisk == nil ? "Thumbnails aren't kept on disk yet." : nil) }
        ) { c, _ -> JSONValue in
            guard let disk = c.thumbnailDisk else {
                throw CatalogError.unavailable(id: "thumbnails.stats", why: "Thumbnails aren't kept on disk yet.")
            }
            let stats = disk.stats
            return .object(["decoded": .number(Double(stats.decoded)), "fromDisk": .number(Double(stats.fromDisk))])
        }
}

/// File > Share… as its menu item reads it: why it can't act now, nil when it can.
public struct LibraryShareMenu: Sendable, Equatable {
    public var help: String?
    public init(help: String?) { self.help = help }
}

extension LibraryCatalog {
    /// File > Share… (`file.share`): the window opens the system's share sheet for the copies `prepareShare` makes,
    /// so the spec stays out of `commands` (and the ledger) like Import Folder… and Export…; it is available while the
    /// menu's help is nil. Run, it sends the caller to `file.share-prepare`, which names the same copies.
    public static let shareMenuSpec: CommandSpec<LibraryShareMenu> =
        .typed("file.share", title: "Share…", summary: "Shares the selected photos, location off.", kind: .file,
               params: NoParams.self, schema: ParamSchema.none, example: .object([:]), availability: { available($0.help) }
        ) { _, _ -> JSONValue in throw CatalogError.unavailable(id: "file.share", why: shareInWindow) }

    /// Why `file.share` doesn't run as a command.
    static let shareInWindow =
        "File > Share… opens the system's share sheet in the window; file.share-prepare makes the copies."
}
