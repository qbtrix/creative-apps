// DesignCommandCatalog.swift (adopt-command-catalog AC-d1): Design's actions as SuiteKernel command specs over
// DesignWorkspace, so a menu, the afterglow CLI and an agent run one path. Each spec's availability is the help the
// window shows today and its run is today's method: every DesignCommand through `help(_:)` and `run(_:)`, the palette
// tools through `unavailableHelp` and `selectTool`, the pages through `addPageHelp`/`deletePageHelp`, and the file
// actions through the toolbar's help. The History panel's history.read and history.jump are SuiteKernel's
// HistoryCommands on the workspace's HistoryJumping adapter (autosave-history DA-6); the six transform.* are
// SuiteKernel's TransformCommands on its TransformTarget (transform DT-6); color.sample is SampleCommands on its
// SampleTarget and color.pick the Eyedropper's click (eyedropper DY-6). Ids are `<menu>.<action>` in lowercase; Tests/command-ids/design.txt keeps them. Linux-safe.
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

    /// Every Design action as a command spec, in menu order, then the History panel's two.
    public static let commands: [CommandSpec<DesignWorkspace>] =
        fileSpecs + editSpecs + objectSpecs + GradientCommands.specs(DesignWorkspace.self) + SampleCommands.specs(DesignWorkspace.self)
            + [pick] + TransformCommands.specs(DesignWorkspace.self) + pageSpecs + toolSpecs + HistoryCommands.specs(DesignWorkspace.self)

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
        plain("file.new", "New File", "Opens a new file with one page holding a Desktop frame.", .edit,
              { reason(DesignToolbarItem.newFile.unavailableHelp(in: $0)) }, { $0.newFile() }),
        .typed("file.open", title: "Open…", summary: "Opens a Design file's text in a window that holds no file.", kind: .file,
               params: TextParams.self, schema: .object(["text": .string("The file's JSON text.")], required: ["text"]),
               example: .object(["text": .string("{}")]),
               availability: { $0.takesOpenedFile ? .available : .unavailable("This window holds a file; open it in a new one.") }
        ) { w, p in try w.open(Data(p.text.utf8)); return JSONValue.object([:]) },
        save("file.save", "Save", "Writes the file and marks it saved; a path becomes where it saves next.", path: .optional(.string("Where it was written."))),
        save("file.save-as", "Save As…", "Writes the file to a new path and marks it saved there.", path: .string("Where it was written.")),
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
            for (index, id) in p.ids.enumerated() { if index == 0 { w.selectItem(id) } else { w.toggleSelection(id) } }
            guard w.selectedNodeIDs == p.ids else { throw DesignRefusal.unknownID(p.ids.joined(separator: ", ")) }
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

    // tool.shape comes from ShapeCommands (shape-tools DS-6).
    static let toolSpecs:[CommandSpec<DesignWorkspace>] = DesignTool.allCases.filter { $0 != .shape }.map { tool in
        let title = tool.rawValue.prefix(1).uppercased() + tool.rawValue.dropFirst()
        return plain("tool." + tool.rawValue, title, "Picks the \(title) tool.", .view, { _ in reason(tool.unavailableHelp) }) { $0.selectTool(tool) }
    }

    /// A menu title as an id part: lowercase words joined by "-" ("Bring to Front" is "bring-to-front").
    static func slug(_ title: String) -> String {
        title.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: "-")
    }
}
