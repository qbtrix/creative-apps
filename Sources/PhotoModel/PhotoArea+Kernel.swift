// PhotoArea+Kernel.swift (area-selection AR-10): Photo's selection as SuiteKernel's area recipe. The ten
// `select.*` area commands (AreaSelectCommands) set the recipe; SuiteImaging's AreaMask turns it into the
// canvas-sized coverage `selectionMask`, and its covered bounds become `selection`, so delete, fill and paint keep
// weighting by `selectionCoverage`. Each change is one undo step that puts back the rectangle, the mask and the
// recipe together. The recipe before the last Deselect or new selection is kept for Reselect. Linux-safe.
import CoreRaster
import SuiteImaging
import SuiteKernel

/// The selection's recipe and the one Reselect restores.
struct PhotoArea: Sendable, Equatable {
    var recipe = AreaRecipe.empty
    var last: AreaRecipe?

    /// Makes `new` the recipe. The old one becomes Reselect's when it selected something and `new` does not
    /// just add steps to it (a Deselect, or a new replace shape).
    mutating func set(_ new: AreaRecipe) {
        if !recipe.isEmpty, !new.steps.starts(with: recipe.steps) { last = recipe }
        recipe = new
    }
}

extension PhotoWorkspace: AreaSelectTarget {
    public var areaHelp: String? { canvas == nil ? Self.noImage : nil }
    /// Empty while nothing is selected, so a resize or crop that dropped the selection leaves nothing to invert.
    public var areaRecipe: AreaRecipe { selection == nil ? .empty : area.recipe }
    public var lastAreaRecipe: AreaRecipe? { area.last }

    /// Renders `recipe` at the canvas's size and makes it the selection: one undo step named for the command.
    public mutating func setAreaRecipe(_ recipe: AreaRecipe) throws {
        try setArea(recipe, command: Self.areaCommand(from: areaRecipe, to: recipe, last: area.last))
    }

    /// `setAreaRecipe` with the undo step named for command `id` (the area tools name theirs by tool).
    mutating func setArea(_ recipe: AreaRecipe, command id: String) throws {
        let before = PhotoEdit.group([.selection(selection, selectionMask), .area(area)])
        try showArea(recipe)
        record(before, named: Self.catalog.spec(id)?.title ?? "Select")
    }

    /// The area command that turns `old` into `new`: the step `new` adds; Reselect when it is `last`; the step a
    /// cancelling Invert dropped; else `new`'s replace shape.
    static func areaCommand(from old: AreaRecipe, to new: AreaRecipe, last: AreaRecipe?) -> String {
        let added = new.steps.count > old.steps.count && new.steps.starts(with: old.steps)
        if !added, new == last { return "select.reselect" }
        let step = added || !old.steps.starts(with: new.steps) ? new.steps.last : old.steps.last
        switch step {
        case .shape(.rect, _): return "select.rect"
        case .shape(.ellipse, _): return "select.ellipse"
        case .shape(.lasso, _): return "select.lasso"
        case .shape(.polygon, _): return "select.polygon"
        case .shape(.wand, _): return "select.wand"
        case .feather: return "select.feather"
        case .expand(let r): return r < 0 ? "select.contract" : "select.expand"
        case .invert, nil: return "select.invert"
        }
    }

    /// The pictures a wand step samples, canvas-sized: the selected layer where it sits, and the composite; nil
    /// when `recipe` has no wand.
    func wandSources(_ recipe: AreaRecipe) throws -> AreaMask.Sources? {
        let wand = recipe.steps.contains { if case .shape(.wand, _) = $0 { true } else { false } }
        guard wand, let canvas else { return nil }
        var layer = try PixelBuffer(width: canvas.width, height: canvas.height)
        if let picked = selectedLayer, let tiled = pixels[picked.id], let bounds = bounds(of: picked),
            let seen = bounds.intersection(canvas.rect)
        {
            let source = try tiled.flattened()
            for y in seen.y..<seen.maxY {
                for x in seen.x..<seen.maxX { try layer.setPixel(x: x, y: y, source.pixel(x: x - bounds.x, y: y - bounds.y)) }
            }
        }
        return AreaMask.Sources(layer: layer, composite: try composite())
    }
}
