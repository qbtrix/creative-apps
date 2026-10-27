// HaloEditMenuSpecs.swift (clipboard-interop CB-halo): what Halo's Edit pasteboard group reads, so every item is
// built from a spec (`MenuCommand(spec, on:)`, command-catalog CC-11). Copy Frame is the catalog's `edit.copy-frame`;
// Paste is the catalog's `edit.paste` and then what the pasteboard offers (its refusal, "Paste: <why>"); Cut, Copy and
// Select All have no Halo command yet, so they are off with why until a text field takes them (the App's
// `givingWay(to:)`). The specs only decide availability: the menu's own action runs the item. Linux-safe.
import SuiteKernel

public struct HaloEditMenuSpecs: Sendable {
    public var menu: HaloMenuState
    /// Why what is on the pasteboard can't be pasted into Halo, or nil when it can (or there's nothing to say).
    public var pasteRefusal: String?

    public init(menu: HaloMenuState, pasteRefusal: String?) {
        self.menu = menu
        self.pasteRefusal = pasteRefusal
    }

    public static let textOnly = "works on text in a field; Halo copies frames, not layers, yet."

    /// Cut, Copy or Select All: never Halo's to run yet, so always off with `textOnly`.
    public static func textOnly(_ id: String, title: String) -> CommandSpec<Self> {
        spec(id, title: title) { _ in .unavailable(textOnly) }
    }

    /// The catalog's `edit.copy-frame` over the menu state.
    public static let copyFrame = spec("edit.copy-frame", title: "Copy Frame") { $0.menu.availability("edit.copy-frame") }

    /// The catalog's `edit.paste`, then the pasteboard's refusal.
    public static let paste = spec("edit.paste", title: "Paste") { state in
        let catalog = state.menu.availability("edit.paste")
        guard catalog.why == nil, let refusal = state.pasteRefusal else { return catalog }
        return .unavailable(refusal)
    }

    private static func spec(
        _ id: String, title: String, availability: @escaping @Sendable (Self) -> Availability
    ) -> CommandSpec<Self> {
        let base = HaloMenuState.spec(id)
        return .typed(id, title: title, summary: base.summary, kind: base.kind, params: JSONValue.self,
                      example: .object([:]), availability: availability) { _, _ in JSONValue.object([:]) }
    }
}
