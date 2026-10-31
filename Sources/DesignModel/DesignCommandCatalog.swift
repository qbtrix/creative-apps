// DesignCommandCatalog.swift (adopt-command-catalog AC-d1): Design's actions as SuiteKernel command specs over
// DesignWorkspace, so a menu, the afterglow CLI and an agent run one path. Each spec's availability is the help the
// window shows today and its run is today's method: every DesignCommand through `help(_:)` and `run(_:)`, the palette
// tools through `unavailableHelp` and `selectTool`, the pages through `addPageHelp`/`deletePageHelp`, and the file
// actions through the toolbar's help. The History panel's history.read and history.jump are SuiteKernel's
// HistoryCommands on the workspace's HistoryJumping adapter (autosave-history DA-6); the six transform.* are
// SuiteKernel's TransformCommands on its TransformTarget (transform DT-6); color.sample is SampleCommands on its
// SampleTarget and color.pick the Eyedropper's click (eyedropper DY-6); shape.draw and tool.shape are ShapeCommands on its
// ShapeTarget (shape-tools DS-6); select.pick, select.enter-group and select.exit-group are GroupPick's on its
// GroupPickTarget (area-selection AR-14); the nine stroke.* are StrokeCommands on its StrokeTarget (stroke-style DK-6);
// edit.copy-as and edit.paste-as-image are CopyAsCommands on DesignPasteboardAdapter's CopyAsTarget (clipboard-interop CB-6);
// the five place.* are PlaceCommands on its PlacedImageTarget (placed-images PD-5).
// Ids are `<menu>.<action>` in lowercase; Tests/command-ids/design.txt keeps them. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension DesignWorkspace {
    /// No params.
    struct NoParams: Codable, Sendable {}
    /// object.nudge's params: the direction and whether it is the large (10 pt, Shift) step.
    struct NudgeParams: Codable, Sendable { var direction: String; var large: Bool? }
    /// edit.select's params: the layers to select, the first one primary until the last.
    struct SelectParams: Codable, Sendable { var ids: [String] }
    /// page.select's params; page.rename's; file.open's; file.save's and file.save-as's.
    struct PageParams: Codable, Sendable { var page: String }
    struct NameParams: Codable, Sendable { var name: String }
    struct TextParams: Codable, Sendable { var text: String }
    struct PathParams: Codable, Sendable { var path: String? }
    /// color.pick's params: the page point and where the colour goes ("fill" or "stroke").
    struct PickParams: Codable, Sendable { var x, y: Double; var to: String }

    /// Every Design action as a command spec, in menu order, the History panel's two after the tools, then the View menu's.
    public static let commands: [CommandSpec<DesignWorkspace>] =
        fileSpecs + editSpecs + CopyAsCommands.specs(DesignWorkspace.self) + objectSpecs + GradientCommands.specs(DesignWorkspace.self) + SampleCommands.specs(DesignWorkspace.self)
            + [pick] + groupSpecs + TransformCommands.specs(DesignWorkspace.self) + pageSpecs + toolSpecs + ShapeCommands.specs(DesignWorkspace.self)
            + StrokeCommands.specs(DesignWorkspace.self)
            + PlaceCommands.specs(DesignWorkspace.self)
            + HistoryCommands.specs(DesignWorkspace.self) + viewSpecs

    /// The specs as a catalog whose history is the workspace's own.
    public static let catalog: CommandCatalog<DesignWorkspace> =
        (try? CommandCatalog(app: "design", commands, history: { $0.history.kernel })) ?? .empty(app: "design")

    /// `help` as an availability: nil is available, a reason is unavailable with it.
    static func reason(_ help: String?) -> Availability { help.map(Availability.unavailable) ?? .available }

    /// A spec with no params that returns nothing.
    static func plain(
        _ id: String, _ title: String, _ summary: String, _ kind: CommandKind,
        _ availability: @escaping @Sendable (DesignWorkspace) -> Availability,
        _ run: @escaping @Sendable (inout DesignWorkspace) throws -> Void
    ) -> CommandSpec<DesignWorkspace> {
        .typed(id, title: title, summary: summary, kind: kind, params: NoParams.self, schema: ParamSchema.none,
               example: .object([:]), availability: availability) { w, _ in try run(&w); return JSONValue.object([:]) }
    }

    /// One selection command: available exactly when `help(_:)` has no reason, run through `run(_:)`.
    static func command(_ id: String, _ title: String, _ summary: String, _ command: DesignCommand) -> CommandSpec<DesignWorkspace> {
        plain(id, title, summary, .edit, { reason($0.help(command)) }, { w in try w.run(command) })
    }

    static let fileSpecs: [CommandSpec<DesignWorkspace>] = [
        .typed("file.new", title: "New File", summary: "Opens a new file with one page of the given size holding a frame in its background.",
               kind: .edit, params: DocumentSetup.self, schema: DocumentSetupCommands.setupSchema,
               example: .object(["width": .number(1080), "height": .number(1920), "background": .string("transparent")]),
               availability: { reason(DesignToolbarItem.newFile.unavailableHelp(in: $0)) }
        ) { w, setup in try w.newFile(setup); return JSONValue.object([:]) },
        .typed("file.open", title: "Open…", summary: "Opens a Design file's text in a window that holds no file.", kind: .file,
               params: TextParams.self, schema: .object(["text": .string("The file's JSON text.")], required: ["text"]),
               example: .object(["text": .string("{}")]),
               availability: { $0.takesOpenedFile ? .available : .unavailable("This window holds a file; open it in a new one.") }
        ) { w, p in try w.open(Data(p.text.utf8)); return JSONValue.object([:]) },
        save("file.save", "Save", "Writes the file and marks it saved; a path becomes where it saves next.", path: .optional(.string("Where it was written."))),
        save("file.save-as", "Save As…", "Writes the file to a new path and marks it saved there.", path: .string("Where it was written.")),
        export,
    ]

    /// file.export's params: the sheet's format, whole scale and scope; its result, the files the run would write.
    struct ExportParams: Codable, Sendable { var format: String; var scale: Int; var scope: String }
    struct ExportedFiles: Encodable, Sendable { var files: [ExportedName] }
    struct ExportedName: Encodable, Sendable { var name: String; var width: Int; var height: Int }

    /// The window's reason for its file-wide View items and Export…: off with no file open.
    static func openHelp(_ w: DesignWorkspace) -> Availability { reason(w.isOpen ? nil : DesignToolbarItem.noFile) }

    /// File > Export…'s confirm: plans the sheet's options and names each file with its pixels. Writing is the window's.
    static let export = CommandSpec<DesignWorkspace>.typed(
        "file.export", title: "Export…", summary: "Plans the files an export writes: the format, the scale and the scope.",
        kind: .file, params: ExportParams.self,
        schema: .object(["format": .string("The file type.", oneOf: DesignExportFormat.allCases.map(\.rawValue)),
                         "scale": .integer("PNG and JPEG's whole scale; vectors take 1.", minimum: 1, maximum: 3),
                         "scope": .string("What it writes.", oneOf: DesignExportScope.allCases.map(\.rawValue))],
                        required: ["format", "scale", "scope"]),
        result: .object(["files": .array(of: .object(["name": .string("The file's name."), "width": .integer("Pixels wide."),
                                                      "height": .integer("Pixels high.")], required: ["name", "width", "height"]))],
                        required: ["files"]),
        example: .object(["format": .string("svg"), "scale": .number(1), "scope": .string("page")]), availability: openHelp
    ) { w, p in
        guard let format = DesignExportFormat(rawValue: p.format), let scope = DesignExportScope(rawValue: p.scope)
        else { throw DesignRefusal.unchanged }
        let plan = try w.exportPlan(DesignExportOptions(format: format, scale: p.scale, scope: scope), existing: [])
        return ExportedFiles(files: plan.map { ExportedName(name: $0.fileName, width: $0.pixelWidth, height: $0.pixelHeight) })
    }

    /// View's zoom items: zoom is the window's, so headless these check availability and change nothing; Zoom to
    /// Selection returns the rect the window would show.
    static let viewSpecs: [CommandSpec<DesignWorkspace>] = [
        plain("view.zoom-in", "Zoom In", "Zooms the window in.", .view, openHelp) { _ in },
        plain("view.zoom-out", "Zoom Out", "Zooms the window out.", .view, openHelp) { _ in },
        plain("view.fit", "Fit Page", "Zooms the window to fit the page.", .view, openHelp) { _ in },
        .typed("view.zoom-to-selection", title: "Zoom to Selection", summary: "Zooms the window to the selected layers.",
               kind: .view, params: NoParams.self, schema: ParamSchema.none,
               result: .object(["x": .number("Left."), "y": .number("Top."), "width": .number("Width."), "height": .number("Height.")],
                               required: ["x", "y", "width", "height"]),
               example: .object([:]), availability: { reason($0.zoomToSelectionHelp) }
        ) { w, _ in
            guard let rect = w.zoomToSelectionRect else { throw DesignRefusal.nothingSelected }
            return rect
        },
    ]

    /// Save and Save As: the file's text as the result; the save marks the session saved, at `path` when given.
    static func save(_ id: String, _ title: String, _ summary: String, path: ParamSchema) -> CommandSpec<DesignWorkspace> {
        .typed(id, title: title, summary: summary, kind: .file, params: PathParams.self,
               schema: .object(["path": path], required: ["path"]),
               result: .object(["text": .string("The file's JSON text.")], required: ["text"]),
               example: .object(["path": .string("Untitled.design")]),
               availability: { reason(DesignToolbarItem.save.unavailableHelp(in: $0)) }
        ) { w, p in
            let text = String(decoding: try w.fileData(), as: UTF8.self)
            if let path = p.path { w.didSave(to: URL(fileURLWithPath: path)) } else { w.sessionDidSave() }
            return ["text": text]
        }
    }

    static let editSpecs: [CommandSpec<DesignWorkspace>] = [
        plain("edit.undo", "Undo", "Puts back the last edit.", .view, { reason(DesignToolbarItem.undo.unavailableHelp(in: $0)) }, { $0.undo() }),
        plain("edit.redo", "Redo", "Makes the last undone edit again.", .view, { reason(DesignToolbarItem.redo.unavailableHelp(in: $0)) }, { $0.redo() }),
        .typed("edit.select", title: "Select", summary: "Selects the layers with these ids, the last one primary.", kind: .view,
               params: SelectParams.self,
               schema: .object(["ids": .array(of: .string("A layer's id."), minItems: 1)], required: ["ids"]),
               example: .object(["ids": .array([.string("node-1")])]), availability: { reason($0.addPageHelp) }
        ) { w, p in
            try w.select(p.ids)
            return JSONValue.object([:])
        },
        plain("edit.select-all", "Select All", "Selects every visible, unlocked layer at the selection's level.", .view,
              { reason($0.addPageHelp) }, { $0.selectAll() }),
        command("edit.duplicate", "Duplicate", "Duplicates the selected layers.", .duplicate),
        command("edit.delete", "Delete", "Deletes the selected layers.", .delete),
    ]

    static let objectSpecs: [CommandSpec<DesignWorkspace>] = [
        command("object.group", "Group", "Groups the selected layers.", .group),
        command("object.ungroup", "Ungroup", "Ungroups the selected groups.", .ungroup),
    ] + DesignArrangeStep.allCases.map(arrange) + DesignAlignEdge.allCases.map(align) + DesignDistributeAxis.allCases.map(distribute) + [nudge]

    /// Arrange, Align and Distribute's items: the id is the menu title slugged under "object.".
    static func arrange(_ step: DesignArrangeStep) -> CommandSpec<DesignWorkspace> { titled(step.title, .arrange(step)) }
    static func align(_ edge: DesignAlignEdge) -> CommandSpec<DesignWorkspace> { titled(edge.title, .align(edge)) }
    static func distribute(_ axis: DesignDistributeAxis) -> CommandSpec<DesignWorkspace> { titled(axis.title, .distribute(axis)) }
    static func titled(_ title: String, _ command: DesignCommand) -> CommandSpec<DesignWorkspace> {
        Self.command("object." + slug(title), title, "Runs \(title) on the selected layers.", command)
    }

    /// object.nudge: 1 pt in `direction`, or 10 pt when `large`, as the arrow keys do with and without Shift.
    static let nudge = CommandSpec<DesignWorkspace>.typed(
        "object.nudge", title: "Nudge", summary: "Moves the selected layers 1 pt, or 10 pt when large.", kind: .edit,
        params: NudgeParams.self,
        schema: .object(["direction": .string("Which way.", oneOf: DesignDirection.allCases.map { "\($0)" }),
                         "large": .optional(.boolean)], required: ["direction", "large"]),
        example: .object(["direction": .string("right")]), availability: { reason($0.help(.nudge(.right, large: false))) }
    ) { w, params in
        guard let direction = DesignDirection.allCases.first(where: { "\($0)" == params.direction }) else { throw DesignRefusal.unchanged }
        try w.run(.nudge(direction, large: params.large ?? false))
        return JSONValue.object([:])
    }

    /// color.pick: the Eyedropper's click as a command, the colour at a page point onto the selection's fill or
    /// stroke as one step (`applySample`, a `sampleSize` square). color.sample is SampleCommands' query.
    static let pick = CommandSpec<DesignWorkspace>.typed(
        "color.pick", title: "Pick Colour", summary: "Sets the selection's fill or stroke to the colour at a page point.", kind: .edit,
        params: PickParams.self,
        schema: .object(["x": .number("Page x."), "y": .number("Page y."), "to": .string("Fill or stroke.", oneOf: ["fill", "stroke"])],
                        required: ["x", "y", "to"]),
        example: .object(["x": .number(10), "y": .number(10), "to": .string("fill")]),
        availability: { reason($0.sampleHelp ?? $0.fillHelp) }
    ) { w, p in
        try w.applySample(at: Point(x: p.x, y: p.y), toStroke: p.to == "stroke", size: w.sampleSize)
        return JSONValue.object([:])
    }

    static let pageSpecs: [CommandSpec<DesignWorkspace>] = [
        plain("page.add", "Add Page", "Adds a page and selects it.", .edit, { reason($0.addPageHelp) }, { $0.addPage() }),
        .typed("page.rename", title: "Rename Page", summary: "Renames the selected page.", kind: .edit, params: NameParams.self,
               schema: .object(["name": .string("The page's new name.", maxLength: 128)], required: ["name"]),
               example: .object(["name": .string("Cover")]), availability: { reason(renamePageHelp($0)) }
        ) { w, p in
            if let id = w.selectedPageID { try w.renamePage(id, to: p.name) }
            return JSONValue.object([:])
        },
        plain("page.delete", "Delete Page", "Deletes the selected page.", .edit, { reason($0.deletePageHelp) }) { w in
            if let id = w.selectedPageID { try w.deletePage(id) }
        },
        .typed("page.select", title: "Select Page", summary: "Selects a page and clears the layer selection.", kind: .view,
               params: PageParams.self, schema: .object(["page": .string("The page's id.")], required: ["page"]),
               example: .object(["page": .string("page-1")]), availability: { reason($0.addPageHelp) }
        ) { w, p in
            guard w.pages.contains(where: { $0.id == p.page }) else { throw DesignRefusal.unknownID(p.page) }
            w.selectPage(p.page)
            return JSONValue.object([:])
        },
    ]

    /// page.rename's reason: the window has no Rename Page help yet, so it is off with no file or mid text edit.
    static func renamePageHelp(_ w: DesignWorkspace) -> String? {
        if w.selectedPage == nil { return DesignToolbarItem.noFile }
        return w.editingTextID == nil ? nil : "Finish editing the text first."
    }

    // tool.shape is ShapeCommands' (shape-tools DS-6), registered beside these.
    static let toolSpecs:[CommandSpec<DesignWorkspace>] = DesignTool.allCases.filter { $0 != .shape }.map { tool in
        let title = tool.rawValue.prefix(1).uppercased() + tool.rawValue.dropFirst()
        return plain("tool." + tool.rawValue, title, "Picks the \(title) tool.", .view, { _ in reason(tool.unavailableHelp) }) { $0.selectTool(tool) }
    }

    /// A menu title as an id part: lowercase words joined by "-" ("Bring to Front" is "bring-to-front").
    static func slug(_ title: String) -> String {
        title.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: "-")
    }
}
