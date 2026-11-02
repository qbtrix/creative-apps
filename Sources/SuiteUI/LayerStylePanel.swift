// LayerStylePanel.swift (layer-styles LS-2 placeholder, LS-3 view): the one layer style panel. Left, the eight kinds
// in StyleKind's order, a switch each; right, the selected kind's LayerStyleRows; under them the host's reason when
// the style commands can't run. Every control sends one StyleIntent through `onIntent`; the panel never edits a
// document. Placeholder: the switches show the style's state but are disabled with their reason (no layer, the
// host's help, or not built yet), so nothing on screen looks live and does nothing. LS-3 adds the selection, Fill
// Opacity, the Presets menu, Done and the switches' intents.
import SuiteImaging
import SuiteKernel
import SwiftUI

public struct LayerStylePanel: View {
    private let style: LayerStyle?
    private let selected: StyleKind
    private let help: String?
    private let onIntent: (StyleIntent) -> Void

    /// `style` is the selected layer's (nil with none), `help` why the style commands can't run now.
    public init(style: LayerStyle?, selected: StyleKind, help: String?, onIntent: @escaping (StyleIntent) -> Void) {
        self.style = style
        self.selected = selected
        self.help = help
        self.onIntent = onIntent
    }

    public var body: some View {
        let reason = LayerStyleText.reason(style: style, help: help)
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(alignment: .top, spacing: SuiteSpacing.m) {
                VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                    ForEach(StyleKind.allCases, id: \.self) { kind in
                        Toggle(LayerStyleText.title(kind), isOn: .constant(style?.effect(kind)?.isEnabled == true))
                            .toggleStyle(.checkbox)
                            .disabled(true)
                            .help(reason)
                            .suiteControl(id: LayerStyleText.toggleID(kind), enabled: false, reason: reason)
                    }
                }
                .frame(width: SuiteSize.inspectorWidth.min, alignment: .leading)
                LayerStyleRows(effect: style?.effect(selected), kind: selected, onIntent: onIntent)
            }
            if let help = help ?? (style == nil ? StyleRules.noLayerHelp : nil) {
                InspectorNote(help, identifier: "suite.style.help")
            }
        }
        .padding(SuiteSpacing.m)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.style.panel")
    }
}

/// The one place a style's JSON goes on and comes off the pasteboard (its own type), so no app writes its own.
/// Placeholder: holds nothing until LS-3 writes it through SuiteModel's pasteboard coding.
public enum LayerStylePasteboard {
    /// Puts `style` (StyleRules.json's form) on the pasteboard. Placeholder: does nothing.
    public static func write(_ style: JSONValue) {}

    /// The style on the pasteboard, nil when it holds none. Placeholder: always nil, so Paste stays disabled.
    public static func read() -> JSONValue? { nil }
}
