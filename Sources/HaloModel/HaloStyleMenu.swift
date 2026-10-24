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
