// GalleryLayerStyle.swift: the gallery's `layer-style` page (layer-styles LS-2; LS-4 runs its intents through
// StyleCommands on a local target). A rounded square on a light canvas beside LayerStylePanel on a local style that
// starts with none. Each intent the panel sends writes one line, `<command id> <intent>`, to `suite.gallery.log`; a
// `show` moves the panel's selection. The preview's value is the enabled kinds ("no style", "dropShadow, outerGlow")
// for the journey. The page is its own area in `SuiteGallery.areas`.
import SuiteImaging
import SwiftUI

enum GalleryLayerStyle {
    static let name = "layer-style"

    static let pages: GalleryPages = [name: { AnyView(GalleryLayerStylePage()) }]

    /// The page's style to start: none.
    static let start = LayerStyle.none

    /// The preview's value: the enabled kinds in order, or "no style".
    static func summary(_ style: LayerStyle) -> String {
        let kinds = style.effects.filter(\.isEnabled).map(\.kind.rawValue)
        return kinds.isEmpty ? "no style" : kinds.joined(separator: ", ")
    }

    /// The log line for `intent`: its command id, then the intent (so a drag token ends the line).
    static func line(_ intent: StyleIntent) -> String { "\(intent.command.id) \(intent)" }
}

/// The `layer-style` page: the preview, the panel and the log under them.
struct GalleryLayerStylePage: View {
    @State private var style = GalleryLayerStyle.start
    @State private var selected = StyleKind.dropShadow
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(alignment: .top, spacing: SuiteSpacing.m) {
                GalleryLayerStylePreview(style: style)
                LayerStylePanel(style: style, selected: selected, help: nil, onIntent: send)
                    .frame(minWidth: SuiteSize.inspectorWidth.ideal)
                    .background(SuiteColor.panel)
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(log.joined(separator: "\n"))
                .accessibilityValue(log.joined(separator: "\n"))
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func send(_ intent: StyleIntent) {
        if case .show(let kind?) = intent { selected = kind }
        log.append(GalleryLayerStyle.line(intent))
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}

/// The preview: a rounded square on a light canvas. LS-4 draws the style on it.
private struct GalleryLayerStylePreview: View {
    let style: LayerStyle

    var body: some View {
        ZStack {
            SuiteColor.artboard
            RoundedRectangle(cornerRadius: SuiteRadius.large)
                .fill(SuiteColor.accentFill)
                .padding(SuiteSpacing.xl)
                .aspectRatio(1, contentMode: .fit)
        }
        .frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
        .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        .accessibilityElement()
        .accessibilityLabel("Layer style preview")
        .accessibilityValue(GalleryLayerStyle.summary(style))
        .accessibilityIdentifier("suite.gallery.layer-style.preview")
    }
}
