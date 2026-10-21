// PhotoCommandCatalog.swift (adopt-command-catalog AC-p1): every Photo menu, toolbar and palette action as one
// command over PhotoWorkspace, ids `<menu>.<action>`. Availability is today's help (PhotoToolbarItem's `unavailableHelp`,
// the Model's menu reasons); run is the method the app calls. An edit's title is its undo step ("Rotate"), `menuTitle(_:)`
// the menu's label ("Rotate 90° Clockwise"). Zoom is window state, so the view.zoom commands are no-ops. Linux-safe.
import CoreRaster
import SuiteKernel

extension PhotoWorkspace {
    /// The params: none; a size in pixels (file.new, image.resize); a name (file.save-as, layer.rename); an image as
    /// straight-alpha RGBA bytes, row by row (file.open, edit.paste); straighten's angle; export's format; an adjustment.
    public struct NoParams: Codable, Sendable {}
    public struct SizeParams: Codable, Sendable { public var width, height: Int }
    public struct NameParams: Codable, Sendable { public var name: String }
    public struct ImageParams: Codable, Sendable { public var name: String?; public var width, height: Int; public var rgba8: [UInt8] }
    public struct StraightenParams: Codable, Sendable { public var degrees: Double; public var cropToFit: Bool }
    public struct ExportParams: Codable, Sendable { public var format: String }
    public struct AdjustmentParams: Codable, Sendable { public var kind: String }

    /// The reasons menu items give that the Model has no help property for.
    static let noImage = "Open an image first.", noLayer = "Select a layer first."
    static let atTop = "The selected layer is already at the top.", atBottom = "The selected layer is already at the bottom."

    /// The catalog of `commands`; empty only if an id broke the id rule.
    public static let catalog = (try? CommandCatalog<PhotoWorkspace>(app: "photo", commands, history: { $0.history.kernel }))
        ?? .empty(app: "photo")

    /// The label the menu shows for `id`: the undo and redo titles name the step, Show/Hide follows the layer.
    public func menuTitle(_ id: String) -> String {
        switch id {
        case "edit.undo": undoActionName
        case "edit.redo": redoActionName
        case "layer.toggle-visibility": visibilityCommandTitle
        default: Self.menuLabels[id] ?? Self.catalog.spec(id)?.title ?? id
        }
    }
    static let menuLabels = [
        "file.open": "Open…", "file.save-as": "Save As…", "file.export": "Export…", "edit.delete-selection": "Delete Selection",
        "edit.fill-selection": "Fill Selection", "image.resize": "Image Size…", "image.rotate-cw": "Rotate 90° Clockwise",
        "image.rotate-ccw": "Rotate 90° Counterclockwise", "image.rotate-180": "Rotate 180°", "image.straighten": "Straighten…",
        "layer.rename": "Rename Layer…", "layer.bring-forward": "Bring Forward", "layer.send-backward": "Send Backward",
    ]
    /// The tooltip of the menu item for `id`: what clicking it does, where the catalog's summary describes the agent call.
    public static func menuSummary(_ id: String) -> String { menuSummaries[id] ?? catalog.spec(id)?.summary ?? id }
    static let menuSummaries = [
        "file.new": "Opens a new white 1920 × 1080 image.", "file.open": "Opens an image file.",
        "file.save": "Saves the image to its file.", "file.save-as": "Saves the image to a new file.",
        "file.export": "Exports a flattened copy of the image.", "image.resize": "Changes the image's size.",
        "image.straighten": "Rotates the image to level it.",
        "layer.new-adjustment": "Adds an adjustment layer above the selected layer.",
    ]

    /// `help`'s reason as an availability: nil is available.
    static func gate(_ help: @escaping @Sendable (PhotoWorkspace) -> String?) -> @Sendable (PhotoWorkspace) -> Availability {
        { help($0).map(Availability.unavailable) ?? .available }
    }
    /// The toolbar item's help.
    static func bar(_ item: PhotoToolbarItem) -> @Sendable (PhotoWorkspace) -> Availability { gate { item.unavailableHelp(in: $0) } }
    /// A menu item that needs an open image, then `more`.
    static func menu(_ more: @escaping @Sendable (PhotoWorkspace) -> String? = { _ in nil }) -> @Sendable (PhotoWorkspace) -> Availability {
        gate { $0.canvas == nil ? noImage : more($0) }
    }
    /// A command with no params and an empty result.
    static func act(_ id: String, _ title: String, _ summary: String, _ kind: CommandKind,
                    _ availability: @escaping @Sendable (PhotoWorkspace) -> Availability,
                    _ run: @escaping @Sendable (inout PhotoWorkspace) throws -> Void) -> CommandSpec<PhotoWorkspace> {
        .typed(id, title: title, summary: summary, kind: kind, params: NoParams.self, schema: ParamSchema.none,
               example: .object([:]), availability: availability) { w, _ in try run(&w); return JSONValue.object([:]) }
    }
    /// The selected layer's id, or the refusal `id` gives without one.
    func selectedID(_ id: String) throws -> PhotoLayer.ID {
        guard let layer = selectedLayerID else { throw CatalogError.unavailable(id: id, why: Self.noLayer) }
        return layer
    }

    static let sizeSchema = ParamSchema.object(["width": .integer("Width in pixels.", minimum: 1),
                                                "height": .integer("Height in pixels.", minimum: 1)], required: ["width", "height"])
    static let nameSchema = ParamSchema.object(["name": .string("The name.", maxLength: 255)], required: ["name"])
    static let imageSchema = ParamSchema.object(
        ["name": .optional(.string("The file's name.", maxLength: 255)), "width": .integer(minimum: 1), "height": .integer(minimum: 1),
         "rgba8": .array(of: .integer(minimum: 0, maximum: 255))], required: ["name", "width", "height", "rgba8"])
    static let sizeExample = JSONValue.object(["width": .number(24), "height": .number(18)])

    /// One command per menu item, toolbar item and palette tool, in menu order.
    public static let commands: [CommandSpec<PhotoWorkspace>] = fileCommands + editCommands + imageCommands + layerCommands
        + FileFlowCommands.specs(PhotoWorkspace.self) + viewCommands + transformCommands + PhotoTool.allCases.map { tool in
            act("tool.\(tool.rawValue)", tool.rawValue.capitalized, "Picks the \(tool.rawValue) tool for canvas drags.", .view,
                gate { $0.toolHelp(tool) }) { $0.selectTool(tool) }
        }

    static let fileCommands: [CommandSpec<PhotoWorkspace>] = [
        .typed("file.new", title: "New Image", summary: "Opens a new white image of the given size.", kind: .file,
               params: SizeParams.self, schema: sizeSchema, example: sizeExample) { w, p in try w.newCanvas(width: p.width, height: p.height); return JSONValue.object([:]) },
        .typed("file.open", title: "Open", summary: "Opens an image from straight-alpha RGBA bytes.", kind: .file, params: ImageParams.self,
               schema: imageSchema, example: .object(["name": .string("dot.png"), "width": .number(1), "height": .number(1), "rgba8": .array([0, 0, 0, 255].map(JSONValue.number))]),
               availability: bar(.open)) { w, p in try w.open(rgba8: p.rgba8, width: p.width, height: p.height, name: p.name ?? "Untitled.png"); return JSONValue.object([:]) },
        act("file.save", "Save", "Marks the image saved under its file name.", .file, bar(.save)) { w in
            let name = w.documentName ?? w.documentFileName
            w.didSave(as: name, kind: fileKind(forName: name))
        },
        .typed("file.save-as", title: "Save As", summary: "Marks the image saved under a new file name.", kind: .file, params: NameParams.self,
               schema: nameSchema, example: .object(["name": .string("copy.ora")]), availability: menu()) { w, p in
            w.didSave(as: p.name, kind: fileKind(forName: p.name)); return JSONValue.object([:])
        },
        .typed("file.export", title: "Export", summary: "Flattens the image for export as png or jpeg.", kind: .file, params: ExportParams.self,
               schema: .object(["format": .string("png or jpeg.", oneOf: ["png", "jpeg"])], required: ["format"]),
               result: .object(["name": .string(), "width": .integer(), "height": .integer()], required: ["name", "width", "height"]),
               example: .object(["format": .string("png")]), availability: bar(.export)) { w, p in
            let format = ImageFormat(rawValue: p.format) ?? .png, image = try w.exportPixels(as: format)
            return ["name": JSONValue.string(w.fileName(for: format)), "width": .number(Double(image.width)), "height": .number(Double(image.height))]
        },
    ]

    static let editCommands: [CommandSpec<PhotoWorkspace>] = [
        act("edit.undo", "Undo", "Undoes the last edit.", .view, bar(.undo)) { $0.undo() },
        act("edit.redo", "Redo", "Redoes the last undone edit.", .view, bar(.redo)) { $0.redo() },
        act("edit.cut", "Cut", "Cuts the selected layer's pixels inside the selection.", .edit, gate { $0.cutHelp }) { _ = $0.cutSelection() },
        .typed("edit.copy", title: "Copy", summary: "Copies the selected layer's pixels inside the selection.", kind: .query,
               params: NoParams.self, schema: ParamSchema.none, result: sizeSchema, example: .object([:]), availability: gate { $0.copyHelp }) { w, _ in
            var copy = w
            guard let image = copy.copySelection()?.image else { throw CatalogError.failed(id: "edit.copy", message: copy.statusMessage ?? "Nothing to copy.") }
            return ["width": image.width, "height": image.height]
        },
        .typed("edit.paste", title: "Paste", summary: "Pastes an image as a new layer above the selected one.", kind: .edit,
               params: ImageParams.self, schema: imageSchema, example: .object(["width": .number(1), "height": .number(1), "rgba8": .array([255, 0, 0, 255].map(JSONValue.number))]),
               availability: gate { $0.pasteHelp(true) }) { w, p in
            let center = Mask.Point(x: Double(w.canvas?.width ?? 0) / 2, y: Double(w.canvas?.height ?? 0) / 2)
            w.paste(ClipboardImage(image: DecodedImage(rgba8: p.rgba8, width: p.width, height: p.height), source: nil), viewCenter: center)
            return JSONValue.object([:])
        },
        act("edit.select-all", "Select All", "Selects the whole image.", .view, gate { $0.canSelectAll ? nil : noImage }) { $0.selectAll() },
        act("edit.delete-selection", "Delete", "Clears the selected pixels of the selected layer.", .edit, menu(selectionHelp)) { $0.deleteSelection() },
        act("edit.fill-selection", "Fill", "Fills the selected pixels with the brush color.", .edit, menu(selectionHelp)) { $0.fillSelection() },
        act("select.all", "All", "Selects the whole image.", .view, gate { $0.canSelectAll ? nil : noImage }) { $0.selectAll() },
        act("select.deselect", "Deselect", "Drops the selection.", .view, menu { $0.canDeselect ? nil : "Nothing is selected." }) { $0.deselect() },
    ]
    static let selectionHelp: @Sendable (PhotoWorkspace) -> String? = { $0.canEditSelection ? nil : "Select part of the selected layer first." }

    static let imageCommands: [CommandSpec<PhotoWorkspace>] = [
        .typed("image.resize", title: "Image Size", summary: "Resamples every layer to the given size.", kind: .edit, params: SizeParams.self,
               schema: sizeSchema, example: sizeExample, availability: menu()) { w, p in try w.resizeImage(width: p.width, height: p.height); return JSONValue.object([:]) },
        act("image.rotate-cw", "Rotate", "Rotates the image 90° clockwise.", .edit, menu()) { $0.rotateImage(.degrees90) },
        act("image.rotate-ccw", "Rotate", "Rotates the image 90° counterclockwise.", .edit, menu()) { $0.rotateImage(.degrees270) },
        act("image.rotate-180", "Rotate", "Rotates the image 180°.", .edit, menu()) { $0.rotateImage(.degrees180) },
        .typed("image.straighten", title: "Straighten", summary: "Rotates the image by an angle, cropped to fit or grown.", kind: .edit, params: StraightenParams.self,
               schema: .object(["degrees": .number("The angle.", minimum: -45, maximum: 45), "cropToFit": .boolean], required: ["degrees", "cropToFit"]),
               example: .object(["degrees": .number(3), "cropToFit": .bool(false)]), availability: menu()) { w, p in
            try w.straighten(degrees: p.degrees, cropToFit: p.cropToFit); return JSONValue.object([:])
        },
    ]

    static let layerCommands: [CommandSpec<PhotoWorkspace>] = [
        act("layer.new", "New Layer", "Adds a transparent layer above the selected one.", .edit, menu()) { $0.addLayer() },
        .typed("layer.new-adjustment", title: "New Adjustment Layer", summary: "Adds an adjustment layer of a kind above the selected layer.",
               kind: .edit, params: AdjustmentParams.self,
               schema: .object(["kind": .string("The adjustment.", oneOf: AdjustmentKind.allCases.map(\.rawValue))], required: ["kind"]),
               example: .object(["kind": .string("levels")]), availability: gate { $0.addAdjustmentLayerHelp }) { w, p in
            guard let kind = AdjustmentKind(rawValue: p.kind), w.adjustmentLayerKinds.contains(kind) else {
                throw CatalogError.failed(id: "layer.new-adjustment", message: "There is no \(p.kind) adjustment layer.")
            }
            w.addAdjustmentLayer(kind); return JSONValue.object([:])
        },
        act("layer.delete", "Delete Layer", "Deletes the selected layer.", .edit, menu { w in
            w.selectedLayer == nil ? noLayer : w.canRemoveLayer ? nil : "The last layer can't be deleted."
        }) { w in _ = w.removeLayer(try w.selectedID("layer.delete")) },
        act("layer.duplicate", "Duplicate Layer", "Duplicates the selected layer.", .edit, gate { $0.duplicateLayerHelp }) { $0.duplicateSelectedLayer() },
        act("layer.merge-down", "Merge Down", "Merges the selected layer into the one below.", .edit, gate { $0.mergeDownHelp }) { $0.mergeDown() },
        act("layer.flatten", "Flatten Image", "Merges every layer into one.", .edit, gate { $0.flattenHelp }) { $0.flattenImage() },
        .typed("layer.rename", title: "Rename Layer", summary: "Renames the selected layer.", kind: .edit, params: NameParams.self,
               schema: nameSchema, example: .object(["name": .string("Sky")]), availability: menu { $0.canEditSelectedLayer ? nil : noLayer }) { w, p in
            w.renameLayer(try w.selectedID("layer.rename"), to: p.name); return JSONValue.object([:])
        },
        act("layer.toggle-visibility", "Hide Layer", "Hides or shows the selected layer.", .edit, menu { $0.canEditSelectedLayer ? nil : noLayer }) { w in w.toggleVisibility(try w.selectedID("layer.toggle-visibility")) },
        act("layer.bring-forward", "Reorder Layers", "Moves the selected layer one place up.", .edit, menu(upHelp)) { $0.bringSelectedLayerForward() },
        act("layer.send-backward", "Reorder Layers", "Moves the selected layer one place down.", .edit, menu(downHelp)) { $0.sendSelectedLayerBackward() },
        act("layer.select-above", "Select Layer Above", "Selects the layer above the selected one.", .view, menu(upHelp)) { $0.selectLayerAbove() },
        act("layer.select-below", "Select Layer Below", "Selects the layer below the selected one.", .view, menu(downHelp)) { $0.selectLayerBelow() },
    ]
    static let upHelp: @Sendable (PhotoWorkspace) -> String? = { $0.selectedLayer == nil ? noLayer : $0.canBringSelectedLayerForward ? nil : atTop }
    static let downHelp: @Sendable (PhotoWorkspace) -> String? = { $0.selectedLayer == nil ? noLayer : $0.canSendSelectedLayerBackward ? nil : atBottom }

    /// The kernel's six transform.* commands, then Free Transform's begin, commit and cancel (transform PT-5).
    static let transformCommands: [CommandSpec<PhotoWorkspace>] = TransformCommands.specs(PhotoWorkspace.self) + [
        act("transform.begin", "Free Transform", "Starts Free Transform on the selected pixel layer.", .view,
            gate { $0.transformHelp }) { try $0.beginTransform() },
        act("transform.commit", "Free Transform", "Resamples the layer into its transformed box as one step.", .edit,
            gate(draftHelp)) { try $0.commitTransform() },
        act("transform.cancel", "Cancel Free Transform", "Drops Free Transform's box, changing no pixels.", .view,
            gate(draftHelp)) { $0.cancelTransform() },
    ]
    static let draftHelp: @Sendable (PhotoWorkspace) -> String? = { $0.transformDraft == nil ? "Start Free Transform first." : nil }

    /// Zoom lives in the window; headless, these check availability and change nothing.
    static let viewCommands: [CommandSpec<PhotoWorkspace>] = [
        act("view.zoom-in", "Zoom In", "Zooms the window in.", .view, bar(.zoomIn)) { _ in },
        act("view.zoom-out", "Zoom Out", "Zooms the window out.", .view, bar(.zoomOut)) { _ in },
        act("view.actual-size", "Actual Size", "Zooms the window to 100%.", .view, menu()) { _ in },
        act("view.fit", "Fit on Screen", "Zooms the window to fit the image.", .view, bar(.fit)) { _ in },
    ]
}
