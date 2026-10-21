// BrushKeyCommands.swift (brush-keys BK-1 specs with real ids, schemas and availability; BK-3 bodies): the six
// brush and opacity commands an app registers with one line, `+ BrushKeyCommands.specs(<X>Workspace.self)`, so the
// keys, the menus and an agent run the same thing.

/// A document the brush keys act on: its active brush, and its selected layers' opacity.
public protocol BrushKeyTarget: Sendable {
    /// The active brush tool's settings; nil with no brush tool.
    var activeBrush: BrushSettings? { get }
    /// Why the selected layers' opacity can't be set now, in the app's words; nil when it can.
    var layerOpacityHelp: String? { get }
    /// Replaces the active brush tool's settings.
    mutating func setActiveBrush(_ s: BrushSettings) throws
    /// Sets every selected layer's opacity to `percent`, one undo step for the whole selection.
    mutating func setSelectedOpacity(_ percent: Double) throws
}

public extension BrushKeyTarget {
    /// No why-not by default: the target's `setSelectedOpacity` refuses on its own terms.
    var layerOpacityHelp: String? { nil }
}

/// The six brush-key commands: four steps and a set on the active brush, and the selected layers' opacity.
public enum BrushKeyCommands {
    /// `brush.set-opacity` and `layer.set-opacity`'s params.
    struct Percent: Codable, Sendable { var percent: Double }
    /// The params of the four steps: none.
    struct Empty: Codable, Sendable {}

    /// Why a brush command can't run.
    public static let noBrushHelp = "Pick a brush tool first."

    static let percent = ParamSchema.object(["percent": .number("0 to 100.", minimum: 0, maximum: 100)], required: ["percent"])
    static let brush = ParamSchema.object(["size": .number("Points."), "hardness": .number("Percent."), "opacity": .number("Percent.")],
                                          required: ["size", "hardness", "opacity"])

    /// The six commands on `target`, in menu order: the brush's four steps and its opacity (view commands: tool
    /// settings, not the document), then the selected layers' opacity, one undo step.
    public static func specs<T: BrushKeyTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            step("brush.size-up", "Larger Brush", "Steps the brush size up: by 1 under 10, 5 under 100, 25 under 300, 50 above."),
            step("brush.size-down", "Smaller Brush", "Steps the brush size down by the band below it: 10 goes to 9."),
            step("brush.hardness-up", "Harder Brush", "Raises the brush's hardness by 25%, to at most 100%."),
            step("brush.hardness-down", "Softer Brush", "Lowers the brush's hardness by 25%, to at least 0%."),
            .typed("brush.set-opacity", title: "Brush Opacity", summary: "Sets the active brush's opacity, 0 to 100 percent.",
                   kind: .view, params: Percent.self, schema: percent, result: brush,
                   example: .object(["percent": .number(50)]), availability: { brushReady($0) }) { _, _ in JSONValue.null },
            .typed("layer.set-opacity", title: "Layer Opacity", summary: "Sets every selected layer's opacity, 0 to 100 percent, as one undo step.",
                   kind: .edit, params: Percent.self, schema: percent,
                   example: .object(["percent": .number(50)]), availability: { layersReady($0) }) { _, _ in JSONValue.null },
        ]
    }

    /// One of the four no-param brush steps.
    static func step<T: BrushKeyTarget>(_ id: String, _ title: String, _ summary: String) -> CommandSpec<T> {
        .typed(id, title: title, summary: summary, kind: .view, params: Empty.self, schema: .none, result: brush,
               example: .object([:]), availability: { brushReady($0) }) { _, _ in JSONValue.null }
    }
    /// Available with a brush tool active; else `noBrushHelp`.
    static func brushReady<T: BrushKeyTarget>(_ target: T) -> Availability {
        target.activeBrush == nil ? .unavailable(noBrushHelp) : .available
    }
    /// Available unless the target says why not.
    static func layersReady<T: BrushKeyTarget>(_ target: T) -> Availability {
        target.layerOpacityHelp.map { .unavailable($0) } ?? .available
    }
}
