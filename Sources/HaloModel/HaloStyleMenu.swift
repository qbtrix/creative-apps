// HaloStyleMenu.swift (layer-styles HY-2): the Layer menu's style items by id, Layer Style…, Copy, Paste and
// Clear Layer Style, and the panel's gestures. Each item's reason is its spec's, nothing copied for Paste, or,
// while the kernel's body is a stub, that it isn't built yet (a dry run on a copy throws `notBuilt`), so no item
// is a dead control and each turns on by itself once LS-6 builds its body. Linux-safe.
import SuiteImaging
import SuiteKernel

extension HaloProject {
    /// Why Paste Layer Style can't run with no style on the pasteboard.
    public static let nothingCopied = "Copy a layer style first."

    /// The Layer menu's style items, in order.
    public static let styleMenuIDs = ["style.panel", "style.copy", "style.paste", "style.clear"]

    /// `id`'s Layer menu title: its spec's, and Layer Style… for the panel.
    public static func styleMenuTitle(_ id: String) -> String {
        id == "style.panel" ? "Layer Style…" : catalog.spec(id)?.title ?? id
    }

    /// Why `id`'s Layer menu item can't run now; nil when it can. `pasted` is the pasteboard's style.
    public func styleMenuHelp(_ id: String, pasted: JSONValue? = nil) -> String? {
        if let why = Self.catalog.availability(id, on: self).why { return why }
        guard id != "style.panel" else { return nil }
        guard let params = Self.styleMenuParams(id, pasted: pasted) else { return Self.nothingCopied }
        var probe = self
        do throws(CatalogError) { _ = try Self.catalog.run(id, params: params, on: &probe) } catch {
            if case .notBuilt(_, let feature) = error { return "Not built yet (\(feature))." }
        }
        return nil
    }

    /// Runs `id`'s Layer menu item: Layer Style… opens the panel at Drop Shadow, Copy returns the style's JSON for
    /// the pasteboard, Paste needs `pasted`. Nil when it refused or returns nothing.
    @discardableResult public mutating func runStyleMenu(_ id: String, pasted: JSONValue? = nil) -> JSONValue? {
        if id == "style.panel" {
            runStyle(.show(.dropShadow))
            return nil
        }
        guard let params = Self.styleMenuParams(id, pasted: pasted) else { return nil }
        return try? Self.catalog.run(id, params: params, on: &self).result
    }

    /// Runs one panel gesture. Showing or closing the panel is this project's own state, so it runs here while
    /// `style.panel`'s kernel body is a stub, opening only where the spec allows; the rest go through the catalog.
    public mutating func runStyle(_ intent: StyleIntent) {
        if case .show(let kind) = intent {
            if kind == nil || Self.catalog.availability("style.panel", on: self).why == nil { showStylePanel(kind) }
            return
        }
        let command = intent.command
        _ = try? Self.catalog.run(command.id, params: command.params, on: &self)
    }

    /// `id`'s params from the menu: none, or Paste's `{style}`; nil for Paste with nothing pasted.
    static func styleMenuParams(_ id: String, pasted: JSONValue?) -> JSONValue? {
        guard id == "style.paste" else { return .object([:]) }
        return pasted.map { .object(["style": $0]) }
    }
}

/// What a Layer menu style item built from its spec reads: the focused project (nil with no Halo window) and the
/// style on the pasteboard, which Paste needs.
public struct HaloStyleMenuState: Sendable {
    public var project: HaloProject?
    public var pasted: JSONValue?

    public init(project: HaloProject?, pasted: JSONValue?) { (self.project, self.pasted) = (project, pasted) }

    /// Why the item for `id` can't run now, worded as `HaloProject.styleMenuHelp`; nil when it can.
    public func why(_ id: String) -> String? {
        guard let project else { return HaloMenuState.noWindow }
        return project.styleMenuHelp(id, pasted: pasted)
    }

    /// The Layer menu item's spec for `id`: its menu title, its catalog summary, available when `why(id)` is nil.
    public static func spec(_ id: String) -> CommandSpec<HaloStyleMenuState> {
        .typed(id, title: HaloProject.styleMenuTitle(id), summary: HaloMenuState.spec(id).summary, kind: .edit,
               params: JSONValue.self, example: .object([:]),
               availability: { state in state.why(id).map(Availability.unavailable) ?? .available }) { state, _ in
            state.project?.runStyleMenu(id, pasted: state.pasted) ?? JSONValue.null
        }
    }

    /// The style sheet's Done: it closes the panel, so it is always available.
    public static let done = CommandSpec<HaloStyleMenuState>.typed(
        "style.panel", title: "Done", summary: "Close the layer style panel.", kind: .view, params: JSONValue.self,
        example: .object([:]), availability: { _ in .available }) { state, _ in
        state.project?.runStyle(.show(nil))
        return JSONValue.null
    }
}
