// LayerStyleRows.swift (layer-styles LS-2 placeholder, LS-3 rows): the selected style's rows in the right column of
// LayerStylePanel, and the words the panel shows. LS-3 gives each kind its rows (colour, blend, opacity, angle,
// distance, size, position, gradient, bevel), each sending one StyleIntent; until then the column names the kind and
// says its settings aren't here yet, and sends nothing.
import SuiteImaging
import SwiftUI

/// The panel's words and identifiers, outside any View so tests call them off the main actor.
public enum LayerStyleText {
    /// Why a control in the placeholder panel can't act yet.
    public static let pending = "Editing layer styles isn't in this build yet."

    /// A kind's name in the list; VoiceOver reads its switch as "<title>, on".
    public static func title(_ kind: StyleKind) -> String {
        switch kind {
        case .dropShadow: "Drop Shadow"
        case .innerShadow: "Inner Shadow"
        case .outerGlow: "Outer Glow"
        case .innerGlow: "Inner Glow"
        case .stroke: "Stroke"
        case .colorOverlay: "Color Overlay"
        case .gradientOverlay: "Gradient Overlay"
        case .bevel: "Bevel & Emboss"
        }
    }

    /// A kind's switch: `suite.style.toggle.<kind>`.
    public static func toggleID(_ kind: StyleKind) -> String { "suite.style.toggle.\(kind.rawValue)" }

    /// Why the switches can't act: the host's reason, no layer selected, or not built yet.
    public static func reason(style: LayerStyle?, help: String?) -> String {
        help ?? (style == nil ? StyleRules.noLayerHelp : pending)
    }
}

/// One kind's rows. Placeholder: its title and a note; LS-3 adds the rows.
public struct LayerStyleRows: View {
    private let effect: StyleEffect?
    private let kind: StyleKind
    private let onIntent: (StyleIntent) -> Void

    public init(effect: StyleEffect?, kind: StyleKind, onIntent: @escaping (StyleIntent) -> Void) {
        self.effect = effect
        self.kind = kind
        self.onIntent = onIntent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text(LayerStyleText.title(kind))
                .font(SuiteFont.inspectorTitle)
                .accessibilityAddTraits(.isHeader)
            InspectorNote("\(LayerStyleText.title(kind)): \(LayerStyleText.pending)", identifier: "suite.style.rows.note")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
