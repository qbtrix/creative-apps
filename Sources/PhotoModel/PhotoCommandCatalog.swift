// PhotoCommandCatalog.swift (adopt-command-catalog AC-p1): every Photo menu, toolbar and palette action as one
// command over PhotoWorkspace, ids `<menu>.<action>`. Availability is today's help (PhotoToolbarItem's `unavailableHelp`,
// the Model's menu reasons); run is the method the app calls. An edit's title is its undo step ("Rotate"), `menuTitle(_:)`
// the menu's label ("Rotate 90° Clockwise"). Zoom is window state, so the view.zoom commands are no-ops. Linux-safe.
import CoreRaster
import FlareCore
import SuiteImaging
import SuiteKernel

extension PhotoWorkspace {
    /// The params: none; a size in pixels (file.new, image.resize); a name (file.save-as, layer.rename); an image as
    /// straight-alpha RGBA bytes, row by row (file.open, edit.paste); straighten's angle; export's format; an adjustment.
    public struct NoParams: Codable, Sendable {}
    public struct SizeParams: Codable, Sendable { public var width, height: Int }
    /// image.canvas-size's: the new size in pixels and the anchor the image keeps its place by.
    public struct CanvasSizeParams: Codable, Sendable { public var width, height: Int; public var anchor: BoxAnchor }
    public struct NameParams: Codable, Sendable { public var name: String }
    public struct ImageParams: Codable, Sendable { public var name: String?; public var width, height: Int; public var rgba8: [UInt8] }
    /// edit.paste-as-image's: a file's name and its bytes in base64, as the shared Paste as Image takes them.
    public struct PasteFileParams: Codable, Sendable { public var name, base64: String }
    public struct StraightenParams: Codable, Sendable { public var degrees: Double; public var cropToFit: Bool }
    /// Export's sheet values: the format and, for JPEG, the quality (0.1...1; the last choice when left out).
    public struct ExportParams: Codable, Sendable { public var format: String; public var quality: Double? }
    /// image.gradient's: "linear" or "radial", stops as sRGB 0...1, and the two points in canvas pixels.
    public struct GradientParams: Codable, Sendable {
        public struct Stop: Codable, Sendable { public var offset, r, g, b, a: Double }
        public struct XY: Codable, Sendable { public var x, y: Double }
        public var type: String; public var stops: [Stop]; public var from, to: XY
    }
    public struct AdjustmentParams: Codable, Sendable { public var kind: String }
    /// layer.pick's layer and click ("replace", "extend" or "toggle"); layer.set-opacity's percent.
    public struct PickParams: Codable, Sendable { public var id, mode: String }
    public struct OpacityParams: Codable, Sendable { public var percent: Double }
    /// layer.move-by's offset, in canvas pixels.
    public struct MoveParams: Codable, Sendable { public var dx, dy: Int }
    /// layer.mask-add's start ("reveal", "hide" or "selection"); layer.mask-enable's state; layer.mask-edit's target.
    public struct MaskAddParams: Codable, Sendable { public var from: String }
    public struct MaskEnableParams: Codable, Sendable { public var enabled: Bool }
    public struct MaskEditParams: Codable, Sendable { public var on: Bool }

    /// The reasons menu items give that the Model has no help property for.
    static let noImage = "Open an image first.", noLayer = "Select a layer first."
    /// Paste as Image's reason on an open image until Photo's pasteboard adapter (clipboard-interop CB-13) reads vector art.
    public static let pasteAsImageHelp = "Paste as image arrives with Photo's pasteboard adapter."
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
        "edit.fill-selection": "Fill Selection", "image.resize": "Image Size…", "image.canvas-size": "Canvas Size…", "image.rotate-cw": "Rotate 90° Clockwise",
        "image.rotate-ccw": "Rotate 90° Counterclockwise", "image.rotate-180": "Rotate 180°", "image.straighten": "Straighten…",
        "layer.rename": "Rename Layer…", "layer.bring-forward": "Bring Forward", "layer.send-backward": "Send Backward",
    ]
    /// The tooltip of the menu item for `id`: what clicking it does, where the catalog's summary describes the agent call.
    public static func menuSummary(_ id: String) -> String { menuSummaries[id] ?? catalog.spec(id)?.summary ?? id }
    static let menuSummaries = [
        "file.new": "Opens a new image at the size, resolution and background you choose.", "file.open": "Opens an image file.",
        "file.save": "Saves the image to its file.", "file.save-as": "Saves the image to a new file.",
        "file.export": "Exports a flattened copy of the image.", "image.resize": "Changes the image's size.",
        "image.canvas-size": "Grows or crops the canvas around an anchor without scaling the image.",
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
    static let pasteFileSchema = ParamSchema.object(["name": .string("The file's name, \"art.svg\".", maxLength: 255),
                                                     "base64": .string("The file's bytes, base64: SVG.")], required: ["name", "base64"])
    static let sizeExample = JSONValue.object(["width": .number(24), "height": .number(18)])
    static let newExample = JSONValue.object(["width": .number(4), "height": .number(6), "unit": .string("in"),
                                              "resolution": .number(300), "background": .string("transparent")])
    static let canvasSizeSchema = ParamSchema.object(
        ["width": .integer("Width in pixels.", minimum: 1), "height": .integer("Height in pixels.", minimum: 1),
         "anchor": .string("The point the image keeps its place by.", oneOf: BoxAnchor.allCases.map(\.rawValue))],
        required: ["width", "height", "anchor"])
    static let canvasSizeExample = JSONValue.object(["width": .number(24), "height": .number(18), "anchor": .string("center")])

    /// One command per menu item, toolbar item and palette tool, in menu order.
    public static let commands: [CommandSpec<PhotoWorkspace>] = fileCommands + editCommands + imageCommands + layerCommands + maskCommands
        + FileFlowCommands.specs(PhotoWorkspace.self) + PlaceCommands.specs(PhotoWorkspace.self) + viewCommands + transformCommands
        + StyleCommands.specs(PhotoWorkspace.self)
        + PhotoTool.allCases.map { tool in
            act("tool.\(tool.rawValue)", tool.rawValue.capitalized, "Picks the \(tool.rawValue) tool for canvas drags.", .view,
                gate { $0.toolHelp(tool) }) { $0.selectTool(tool) }
        }
        + HistoryCommands.specs(PhotoWorkspace.self) + SampleCommands.specs(PhotoWorkspace.self) + textCommands + pathCommands
        + ToneCommands.specs(PhotoWorkspace.self)

    static let fileCommands: [CommandSpec<PhotoWorkspace>] = [
        .typed("file.new", title: "New Image", summary: "Opens a new image at a size, unit, resolution and background.", kind: .file,
               params: DocumentSetup.self, schema: DocumentSetupCommands.setupSchema, example: newExample) { w, p in
            try w.newImage(p); return JSONValue.object([:])
        },
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
        .typed("file.export", title: "Export", summary: "Flattens the image for export as png or jpeg.",
               kind: .file, params: ExportParams.self,
               schema: .object(["format": .string("png or jpeg.", oneOf: ["png", "jpeg"]),
                                "quality": .optional(.number("JPEG quality.", minimum: 0.1, maximum: 1))], required: ["format", "quality"]),
               result: .object(["name": .string(), "width": .integer(), "height": .integer(), "quality": .number()],
                               required: ["name", "width", "height", "quality"]),
               example: .object(["format": .string("png")]), availability: bar(.export)) { w, p in
            let format = ImageFormat(rawValue: p.format) ?? .png, image = try w.exportPixels(as: format)
            let o = ExportOptions(format: format, quality: p.quality ?? w.exportOptions.quality, size: w.exportOptions.size)
            // The sheet's confirm starts its one write on the choice; without the sheet, the choice is kept for next time.
            if !w.startExport(o) { w.exportOptions = o }
            return ["name": JSONValue.string(w.fileName(for: format)), "width": .number(Double(image.width)),
                    "height": .number(Double(image.height)), "quality": .number(o.quality)]
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
        .typed("edit.paste-as-image", title: "Paste as Image", summary: "Pastes vector art by name as pixels on a new layer, rasterized at the canvas size.",
               kind: .edit, params: PasteFileParams.self, schema: pasteFileSchema,
               example: .object(["name": .string("art.svg"), "base64": .string("PHN2Zy8+")]),
               availability: menu { _ in pasteAsImageHelp }) { _, _ -> JSONValue in
            throw CatalogError.unavailable(id: "edit.paste-as-image", why: pasteAsImageHelp)
        },
        act("edit.select-all", "Select All", "Selects the whole image.", .view, gate { $0.canSelectAll ? nil : noImage }) { $0.selectAll() },
        act("edit.delete-selection", "Delete", "Clears the selected pixels of the selected layer.", .edit, menu(selectionHelp)) { $0.deleteSelection() },
        act("edit.fill-selection", "Fill", "Fills the selected pixels with the brush color.", .edit, menu(selectionHelp)) { $0.fillSelection() },
        act("select.all", "All", "Selects the whole image.", .view, gate { $0.canSelectAll ? nil : noImage }) { $0.selectAll() },
        act("select.deselect", "Deselect", "Drops the selection.", .view, menu { $0.canDeselect ? nil : "Nothing is selected." }) { $0.deselect() },
    ] + AreaSelectCommands.specs(PhotoWorkspace.self)
    static let selectionHelp: @Sendable (PhotoWorkspace) -> String? = { $0.canEditSelection ? nil : "Select part of the selected layer first." }

    static let imageCommands: [CommandSpec<PhotoWorkspace>] = [
        .typed("image.resize", title: "Image Size", summary: "Resamples every layer to the given size.", kind: .edit, params: SizeParams.self,
               schema: sizeSchema, example: sizeExample, availability: menu()) { w, p in try w.resizeImage(width: p.width, height: p.height); return JSONValue.object([:]) },
        .typed("image.canvas-size", title: "Canvas Size", summary: "Pads or crops the canvas to the given size about the anchor.",
               kind: .edit, params: CanvasSizeParams.self, schema: canvasSizeSchema, example: canvasSizeExample,
               availability: menu { $0.flipHelp }) { w, p in
            try w.resizeCanvas(width: p.width, height: p.height, anchor: p.anchor); return JSONValue.object([:])
        },
        act("image.rotate-cw", "Rotate", "Rotates the image 90° clockwise.", .edit, menu()) { $0.rotateImage(.degrees90) },
        act("image.rotate-ccw", "Rotate", "Rotates the image 90° counterclockwise.", .edit, menu()) { $0.rotateImage(.degrees270) },
        act("image.rotate-180", "Rotate", "Rotates the image 180°.", .edit, menu()) { $0.rotateImage(.degrees180) },
    ] + CropCommands.orientationSpecs(PhotoWorkspace.self).filter { $0.id == "image.flip" } + [
        .typed("image.straighten", title: "Straighten", summary: "Rotates the image by an angle, cropped to fit or grown.", kind: .edit, params: StraightenParams.self,
               schema: .object(["degrees": .number("The angle.", minimum: -45, maximum: 45), "cropToFit": .boolean], required: ["degrees", "cropToFit"]),
               example: .object(["degrees": .number(3), "cropToFit": .bool(false)]), availability: menu()) { w, p in
            try w.straighten(degrees: p.degrees, cropToFit: p.cropToFit); return JSONValue.object([:])
        },
        .typed("image.gradient", title: "Gradient", summary: "Draws a dithered gradient into the selected layer, inside the selection.",
               kind: .edit, params: GradientParams.self, schema: gradientSchema, example: gradientExample,
               availability: menu { $0.selectedLayer == nil ? noLayer : nil }) { w, p in
            try w.drawGradient(gradientFill(p), from: Mask.Point(x: p.from.x, y: p.from.y), to: Mask.Point(x: p.to.x, y: p.to.y))
            return JSONValue.object([:])
        },
    ]
    static let gradientSchema: ParamSchema = {
        let unit = ParamSchema.number("0...1.", minimum: 0, maximum: 1)
        let xy = ParamSchema.object(["x": .number("In pixels."), "y": .number("In pixels.")], required: ["x", "y"])
        let stop = ParamSchema.object(["offset": unit, "r": unit, "g": unit, "b": unit, "a": unit], required: ["offset", "r", "g", "b", "a"],
                                      description: "A stop: where it sits and its sRGB color.")
        return .object(["type": .string("The shape.", oneOf: ["linear", "radial"]), "stops": .array(of: stop, minItems: 2),
                        "from": xy, "to": xy], required: ["type", "stops", "from", "to"])
    }()
    static let gradientExample = JSONValue.object([
        "type": .string("linear"), "from": .object(["x": .number(0), "y": .number(0)]), "to": .object(["x": .number(0), "y": .number(11)]),
        "stops": .array([0.0, 1.0].map { v in
            .object(["offset": .number(v), "r": .number(v), "g": .number(v), "b": .number(v), "a": .number(1)])
        }),
    ])
    /// The kernel `Fill` image.gradient's params describe, its stops in offset order.
    static func gradientFill(_ p: GradientParams) -> Fill {
        let stops = p.stops.sorted { $0.offset < $1.offset }.map { GradientStop(offset: $0.offset, color: Color(r: $0.r, g: $0.g, b: $0.b, a: $0.a)) }
        return p.type == "radial" ? .radial(stops: stops, center: Point(x: 0, y: 0), radius: 1)
            : .linear(stops: stops, start: Point(x: 0, y: 0), end: Point(x: 1, y: 0))
    }

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
        act("layer.delete", "Delete Layer", "Deletes the selected layers.", .edit, menu { $0.deleteLayersHelp }) { w in _ = try w.selectedID("layer.delete"); w.removeSelectedLayers() },
        act("layer.duplicate", "Duplicate Layer", "Duplicates the selected layer.", .edit, gate { $0.duplicateLayerHelp }) { $0.duplicateSelectedLayer() },
        act("layer.merge-down", "Merge Down", "Merges the selected layer into the one below.", .edit, gate { $0.mergeDownHelp }) { $0.mergeDown() },
        act("layer.flatten", "Flatten Image", "Merges every layer into one.", .edit, gate { $0.flattenHelp }) { $0.flattenImage() },
        .typed("layer.rename", title: "Rename Layer", summary: "Renames the selected layer.", kind: .edit, params: NameParams.self,
               schema: nameSchema, example: .object(["name": .string("Sky")]), availability: menu { $0.canEditSelectedLayer ? nil : noLayer }) { w, p in
            w.renameLayer(try w.selectedID("layer.rename"), to: p.name); return JSONValue.object([:])
        },
        act("layer.toggle-visibility", "Hide Layer", "Hides or shows the selected layers.", .edit, menu { $0.canEditSelectedLayer ? nil : noLayer }) { w in w.toggleVisibility(try w.selectedID("layer.toggle-visibility")) },
        act("layer.bring-forward", "Reorder Layers", "Moves the selected layer one place up.", .edit, menu(upHelp)) { $0.bringSelectedLayerForward() },
        act("layer.send-backward", "Reorder Layers", "Moves the selected layer one place down.", .edit, menu(downHelp)) { $0.sendSelectedLayerBackward() },
        act("layer.select-above", "Select Layer Above", "Selects the layer above the selected one.", .view, menu(upHelp)) { $0.selectLayerAbove() },
        act("layer.select-below", "Select Layer Below", "Selects the layer below the selected one.", .view, menu(downHelp)) { $0.selectLayerBelow() },
        .typed("layer.pick", title: "Select Layer", summary: "Picks a layer: replace, extend (Shift) or toggle (Command).", kind: .view,
               params: PickParams.self, schema: .object(["id": .string("The layer's id.", maxLength: 255),
                                                         "mode": .string("The click.", oneOf: pickModes.map(\.name))], required: ["id", "mode"]),
               example: .object(["id": .string("layer-1"), "mode": .string("replace")]), availability: menu()) { w, p in
            guard w.index(of: p.id) != nil, let pick = pickModes.first(where: { $0.name == p.mode })?.pick else {
                throw CatalogError.failed(id: "layer.pick", message: "There is no layer \(p.id) to pick by \(p.mode).")
            }
            w.pickLayer(p.id, pick); return JSONValue.object([:])
        },
        act("layer.select-all", "Select All Layers", "Picks every layer.", .view, menu()) { $0.selectAllLayers() },
        .typed("layer.set-opacity", title: "Layer Opacity", summary: "Sets the selected layers' opacity, 0 to 100 percent.", kind: .edit,
               params: OpacityParams.self, schema: .object(["percent": .number("Opacity in percent.", minimum: 0, maximum: 100)], required: ["percent"]),
               example: .object(["percent": .number(50)]), availability: menu { $0.canEditSelectedLayer ? nil : noLayer }) { w, p in
            let id = try w.selectedID("layer.set-opacity")
            w.endAdjust(); w.setOpacity(id, percent: p.percent); w.endAdjust(); return JSONValue.object([:])
        },
        .typed("layer.move-by", title: "Move Layer", summary: "Moves the selected layers by dx, dy pixels.", kind: .edit,
               params: MoveParams.self, schema: .object(["dx": .integer("Pixels right.", minimum: -10_000_000, maximum: 10_000_000),
                                                         "dy": .integer("Pixels down.", minimum: -10_000_000, maximum: 10_000_000)], required: ["dx", "dy"]),
               example: .object(["dx": .number(40), "dy": .number(0)]), availability: menu { $0.canEditSelectedLayer ? nil : noLayer }) { w, p in
            w.moveSelectedLayers(dx: p.dx, dy: p.dy); return JSONValue.object([:])
        },
    ]
    /// Layer masks (masks-clipping PK-1): each an undo step but Edit Mask, which only points the brush.
    static let maskCommands: [CommandSpec<PhotoWorkspace>] = [
        .typed("layer.mask-add", title: "Add Layer Mask", summary: "Adds a mask to the selected layer: reveal all, hide all or the selection.",
               kind: .edit, params: MaskAddParams.self,
               schema: .object(["from": .string("What the mask starts as.", oneOf: MaskStart.allCases.map(\.rawValue))], required: ["from"]),
               example: .object(["from": .string("reveal")]), availability: gate { $0.addMaskHelp(.reveal) }) { w, p in
            guard let start = MaskStart(rawValue: p.from) else {
                throw CatalogError.failed(id: "layer.mask-add", message: "A mask can't start as \(p.from).")
            }
            try w.addMask(start); return JSONValue.object([:])
        },
        act("layer.mask-delete", "Delete Layer Mask", "Deletes the selected layer's mask.", .edit, gate { $0.maskHelp }) { try $0.deleteMask() },
        act("layer.mask-apply", "Apply Layer Mask", "Bakes the selected layer's mask into its pixels.", .edit, gate { $0.maskHelp }) { try $0.applyMask() },
        .typed("layer.mask-enable", title: "Disable Layer Mask", summary: "Turns the selected layer's mask off or back on, keeping it.",
               kind: .edit, params: MaskEnableParams.self, schema: .object(["enabled": .boolean], required: ["enabled"]),
               example: .object(["enabled": .bool(false)]), availability: gate { $0.maskHelp }) { w, p in
            try w.setMaskEnabled(p.enabled); return JSONValue.object([:])
        },
        .typed("layer.mask-edit", title: "Edit Layer Mask", summary: "Points the brush and eraser at the selected layer's mask, or back at its pixels.",
               kind: .view, params: MaskEditParams.self, schema: .object(["on": .boolean], required: ["on"]),
               example: .object(["on": .bool(true)]), availability: gate { $0.maskHelp }) { w, p in
            w.setEditsMask(p.on); return JSONValue.object([:])
        },
    ]
    static let pickModes: [(name: String, pick: Pick)] = [("replace", .replace), ("extend", .extend), ("toggle", .toggle)]
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
