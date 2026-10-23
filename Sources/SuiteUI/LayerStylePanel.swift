// LayerStylePanel.swift (layer-styles LS-2 placeholder, LS-3 view): the one layer style panel. Left, the eight kinds
// in StyleKind's order, a switch each; right, the selected kind's LayerStyleRows; under them the host's reason when
// the style commands can't run. Every control sends one StyleIntent through `onIntent`; the panel never edits a
// document. LS-3: a button per kind shows its rows, then Fill Opacity, the Presets menu and Done.
import AppKit
import SuiteImaging
import SuiteKernel
import SwiftUI

/// One kind's switch: on when the layer has the kind enabled; `set` sends `.toggle` only when it can act and changes.
public struct StyleSwitch: Identifiable {
    public let kind: StyleKind, isOn: Bool, reason: String?
    let onIntent: (StyleIntent) -> Void
    public var id: String { LayerStyleText.toggleID(kind) }
    public var title: String { LayerStyleText.title(kind) }
    public func set(_ on: Bool) { if reason == nil, on != isOn { onIntent(.toggle(kind, on)) } }
}

public struct LayerStylePanel: View {
    private let style: LayerStyle?
    private let selected: StyleKind
    private let help: String?
    private let presets: [StylePreset]
    private let onIntent: (StyleIntent) -> Void
    @State private var scrub = StyleScrub()

    /// `style` is the selected layer's (nil with none), `help` why the style commands can't run now.
    public init(style: LayerStyle?, selected: StyleKind, help: String?, presets: [StylePreset] = StyleRules.presets,
                onIntent: @escaping (StyleIntent) -> Void) {
        self.style = style
        self.selected = selected
        self.help = help
        self.presets = presets
        self.onIntent = onIntent
    }

    public var body: some View {
        let blocked = LayerStyleText.blocked(style: style, help: help)
        let presetsHelp = Self.presetsHelp(presets, blocked: blocked)
        let done = Self.done(onIntent: onIntent)
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(alignment: .top, spacing: SuiteSpacing.m) {
                VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                    ForEach(Self.switches(style: style, help: help, onIntent: onIntent)) { item in
                        HStack(spacing: SuiteSpacing.xs) {
                            Toggle(item.title, isOn: Binding(get: { item.isOn }, set: { item.set($0) }))
                                .toggleStyle(.checkbox).labelsHidden()
                                .disabled(item.reason != nil).help(item.reason ?? item.title)
                                .suiteControl(id: item.id, enabled: item.reason == nil, reason: item.reason)
                            InspectorAction(Self.kindAction(item.kind, selected: selected, onIntent: onIntent))
                        }
                    }
                    InspectorSliderRow("Fill Opacity", value: (style?.fillOpacity ?? 1) * 100, in: 0...100, step: 1, unit: "%",
                                       decimals: 0, onChange: { fillOpacity($0) }, onEnd: { if scrub.token != nil { scrub.end() } })
                        .disabled(blocked != nil).help(blocked ?? "")
                        .suiteControl(id: Self.fillOpacityID, enabled: blocked == nil, reason: blocked)
                }
                .frame(width: SuiteSize.inspectorWidth.min, alignment: .leading)
                LayerStyleRows(effect: style?.effect(selected), kind: selected, help: blocked, onIntent: onIntent)
            }
            if let blocked { InspectorNote(blocked, identifier: "suite.style.help") }
            HStack(spacing: SuiteSpacing.s) {
                Menu("Presets") {
                    ForEach(Self.presetActions(presets, blocked: blocked, onIntent: onIntent)) { item in
                        Button(item.title, action: item.perform).accessibilityIdentifier(item.identifier ?? "")
                    }
                }
                .fixedSize().disabled(presetsHelp != nil).help(presetsHelp ?? "Apply a saved style")
                .suiteControl(id: Self.presetsID, enabled: presetsHelp == nil, reason: presetsHelp)
                Spacer()
                Button(done.title, action: done.perform).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).suiteControl(done)
            }
        }
        .padding(SuiteSpacing.m)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.style.panel")
    }

    /// One Fill Opacity sample under the drag's token; @State changes only when the drag opens it (SwiftUI rule 1).
    private func fillOpacity(_ shown: Double) {
        var next = scrub
        let drag = next.open()
        if next != scrub { scrub = next }
        onIntent(.fillOpacity(shown / 100, drag: drag))
    }
    nonisolated static let fillOpacityID = "suite.style.fill-opacity", presetsID = "suite.style.presets"

    /// The eight switches in StyleKind's order, disabled with `LayerStyleText.blocked`'s reason.
    nonisolated public static func switches(style: LayerStyle?, help: String?, onIntent: @escaping (StyleIntent) -> Void) -> [StyleSwitch] {
        let reason = LayerStyleText.blocked(style: style, help: help)
        return StyleKind.allCases.map { StyleSwitch(kind: $0, isOn: style?.effect($0)?.isEnabled == true, reason: reason, onIntent: onIntent) }
    }
    /// The button that shows `kind`'s rows: `suite.style.kind.<kind>`, selected while they show.
    nonisolated static func kindAction(_ kind: StyleKind, selected: StyleKind, onIntent: @escaping (StyleIntent) -> Void) -> ToolbarAction {
        ToolbarAction(LayerStyleText.title(kind), systemImage: "slider.horizontal.3", isSelected: kind == selected,
                      identifier: "suite.style.kind.\(kind.rawValue)") { onIntent(.show(kind)) }
    }
    /// The Presets menu's items, each sending `.preset(name)`: `suite.style.preset.<name>`.
    nonisolated public static func presetActions(_ presets: [StylePreset], blocked: String?, onIntent: @escaping (StyleIntent) -> Void) -> [ToolbarAction] {
        presets.map { p in
            ToolbarAction(p.name, systemImage: "wand.and.stars", unavailableHelp: blocked, identifier: "suite.style.preset.\(p.name)") { onIntent(.preset(p.name)) }
        }
    }
    /// Why the Presets menu can't open: the panel's reason, or no presets; nil when it can.
    nonisolated public static func presetsHelp(_ presets: [StylePreset], blocked: String?) -> String? {
        blocked ?? (presets.isEmpty ? "No style presets in this build yet." : nil)
    }
    nonisolated public static func done(onIntent: @escaping (StyleIntent) -> Void) -> ToolbarAction {
        ToolbarAction("Done", systemImage: "checkmark", identifier: "suite.style.done") { onIntent(.show(nil)) }
    }
    /// Every control identifier the panel draws with `selected`'s rows showing, in screen order.
    nonisolated public static func controlIDs(style: LayerStyle?, selected: StyleKind, presets: [StylePreset]) -> [String] {
        let kinds = StyleKind.allCases.flatMap { [LayerStyleText.toggleID($0), kindAction($0, selected: selected) { _ in }.identifier ?? ""] }
        let rows = StyleEdit.fields(style?.effect(selected) ?? StyleRules.defaults(selected)).flatMap(\.ids)
        let menu = presetActions(presets, blocked: nil) { _ in }.compactMap(\.identifier)
        return kinds + [fillOpacityID] + rows + [presetsID] + menu + [done { _ in }.identifier ?? ""]
    }
}

/// The one place a style's JSON goes on and comes off the pasteboard (its own type), so no app writes its own.
@MainActor public enum LayerStylePasteboard {
    static let type = NSPasteboard.PasteboardType("org.creative-apps.layer-style")

    /// Puts `style` (StyleRules.json's form) on the general pasteboard; one that won't encode leaves it as it is.
    public static func write(_ style: JSONValue) {
        guard let data = try? style.json() else { return }
        NSPasteboard.general.declareTypes([type], owner: nil)
        NSPasteboard.general.setData(data, forType: type)
    }
    /// The style on the pasteboard, nil when it holds none.
    public static func read() -> JSONValue? { NSPasteboard.general.data(forType: type).flatMap { try? JSONValue(json: $0) } }
}
