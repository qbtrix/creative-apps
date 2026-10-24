// PathSelect.swift (#5072): a path made a selection, for an app that both edits paths (`PathEditTarget`) and
// selects areas (`AreaSelectTarget`); it adds `+ PathSelect.specs(<X>Workspace.self)`. `select.path` flattens the
// path in edit, mapped to document space, into one closed polygon per contour (an open contour closes from its last
// point to its first), joins the first to the selection by the mode and adds the rest, and sets the recipe once:
// one undo step. SuiteImaging's AreaMask renders it like any other area.
import FlareCore

public enum PathSelect {
    /// How far a flattened polygon may stray from its curve, in document pixels.
    public static let tolerance = 0.25
    public static let noPathHelp = "Select a path first.", noAreaHelp = "The path encloses no area to select."
    struct ModeParams: Codable, Sendable { var mode: AreaCombine? }

    /// `select.path` on `target`.
    public static func specs<T: PathEditTarget & AreaSelectTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [.typed("select.path", title: "Make Selection from Path", summary: "Selects inside the path in edit, joined to the selection by a mode.",
                kind: .edit, params: ModeParams.self,
                schema: .object(["mode": .optional(.string("How the path joins the selection; replace when left out.",
                                                            oneOf: AreaCombine.allCases.map(\.rawValue)))], required: ["mode"]),
                example: .object([:]),
                availability: { t in
                    if let help = t.areaHelp { return .unavailable(help) }
                    return t.pathInEdit == nil ? .unavailable(noPathHelp) : .available
                }) { t, p in
            guard let edit = t.pathInEdit else { throw CatalogError.unavailable(id: "select.path", why: noPathHelp) }
            let shapes = try polygons(edit)
            guard let first = shapes.first else { throw CatalogError.unavailable(id: "select.path", why: noAreaHelp) }
            var recipe = t.areaRecipe
            recipe.apply(.shape(first, p.mode ?? .replace))
            // ponytail: contours are unioned, so a contour inside another fills its hole; an even-odd fill would cut it.
            for shape in shapes.dropFirst() { recipe.apply(.shape(shape, .add)) }
            try t.setAreaRecipe(recipe.normalized())
            return JSONValue.object([:])
        }]
    }

    /// One closed polygon per contour of `edit`'s path in document space that has at least three distinct points.
    public static func polygons(_ edit: PathInEdit) throws -> [AreaShape] {
        let rings = try VectorPath(contours: edit.path.contours.map { VectorContour(anchors: $0.anchors, closed: true) })
            .transformed(by: edit.toDocument).flattened(tolerance: tolerance)
        return rings.compactMap { ring in
            var points = ring
            if points.count > 1, points.first == points.last { points.removeLast() }
            guard Set(points.map { [$0.x, $0.y] }).count >= 3, points.allSatisfy(\.isFinite) else { return nil }
            return .polygon(points + [points[0]])
        }
    }
}
