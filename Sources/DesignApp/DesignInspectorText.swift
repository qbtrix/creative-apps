// DesignInspectorText.swift: the Text section of Design's inspector, shown
// after Fill for every selected layer (style-rows, SR-t). Family is a
// picker over the system's font families, Size a scrub field (1...1000 pt),
// Weight and Alignment chips. Every row reads the style the selected text
// layers share (`sharedTextStyle`), or "Mixed" when they differ, and each
// change is one `.setStyle(.textStyle(...))`, one "Change Text Style" step
// that sets only the text layers. Size commits on Return, on focus loss, on
// an arrow key and at the end of a drag, never per drag sample (rule 1;
// DW-b's live preview replaces the wait). The rows are disabled with the
// Model's `styleHelp(.textStyle)` as their tooltip and as a hint line ("A
// isn't a text layer."). Values in, intents out.
import AppKit
import DesignModel
import SuiteUI
import SwiftUI

/// Whether the Size field is mid-drag, and the size it will commit when the drag ends.
/// Not observed, so a drag sample writes nothing SwiftUI watches.
@MainActor final class TextSizeScrub {
    var dragging = false
    var pending: Double?
}

/// The selected layers' Text section: Family, Size, Weight and Alignment.
struct DesignInspectorText: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    @State private var scrub = TextSizeScrub()

    static let weights: [InspectorOption<Int>] = [
        (100, "Thin"), (200, "Extra Light"), (300, "Light"), (400, "Regular"), (500, "Medium"),
        (600, "Semibold"), (700, "Bold"), (800, "Heavy"), (900, "Black"),
    ].map { InspectorOption(id: $0.0, title: $0.1) }

    static let alignments: [InspectorOption<DesignTextAlignment>] = [
        InspectorOption(id: .leading, title: "Left"), InspectorOption(id: .center, title: "Center"),
        InspectorOption(id: .trailing, title: "Right"),
    ]

    /// "System" first, then the families installed on this Mac.
    private static let families: [String] = ["System"] + NSFontManager.shared.availableFontFamilies

    /// The style every selected text layer shares, or nil ("Mixed") when they differ. With no text
    /// layer selected the rows show the default style, disabled with the reason.
    var style: DesignTextStyle? {
        model.selectedNodes.contains { $0.kind == .text } ? model.sharedTextStyle : .default
    }

    /// Why the rows can't edit the selection, or nil when they can.
    var help: String? { model.styleHelp(.textStyle) }

    var body: some View {
        let help = self.help
        let style = self.style
        InspectorSection("Text") {
            VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                familyRow(style, help: help)
                InspectorRow("Size") {
                    if let style {
                        ScrubField("Font size", value: style.size, in: 1...1000, step: 1, unit: "pt", decimals: 0) {
                            sizeChanged($0, in: scrub)
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in scrub.dragging = true }
                                .onEnded { _ in sizeDragEnded(in: scrub) })
                        .disabled(help != nil)
                        .help(help ?? "")
                        .suiteControl(id: DesignControlID.inspectorTextSize, enabled: help == nil, reason: help)
                    } else {
                        mixed(help, id: DesignControlID.inspectorTextSize)
                    }
                }
                chipsRow("Weight", options: Self.weights, selected: style?.weight, help: help,
                         id: DesignControlID.inspectorTextWeight) { weight in
                    commit { $0.weight = weight }
                }
                chipsRow("Alignment", options: Self.alignments, selected: style?.alignment, help: help,
                         id: DesignControlID.inspectorTextAlignment) { alignment in
                    commit { $0.alignment = alignment }
                }
                if let help { InspectorNote(help) }
            }
        }
    }

    /// The Family picker; a mixed selection shows "Mixed" until a family is picked.
    private func familyRow(_ style: DesignTextStyle?, help: String?) -> some View {
        let current = style?.family ?? ""
        var names = Self.families
        if !current.isEmpty, !names.contains(current) { names.insert(current, at: 0) }
        let options = (current.isEmpty ? [InspectorOption(id: "", title: "Mixed")] : [])
            + names.map { InspectorOption(id: $0, title: $0) }
        return InspectorPickerRow("Family", options: options, selection: current) { family in
            if !family.isEmpty { commit { $0.family = family } }
        }
        .disabled(help != nil)
        .help(help ?? "")
        .accessibilityValue(Text(verbatim: style?.family ?? "Mixed"))
        .suiteControl(id: DesignControlID.inspectorTextFamily, enabled: help == nil, reason: help)
    }

    /// A label over a chip group; the group is one container carrying `id`, its chips found by title.
    private func chipsRow<ID: Hashable & Sendable>(
        _ label: String, options: [InspectorOption<ID>], selected: ID?, help: String?, id: String,
        onSelect: @escaping @MainActor (ID) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            HStack(spacing: SuiteSpacing.xs) {
                Text(label).font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.textSecondary)
                if selected == nil {
                    Text("Mixed").font(SuiteFont.inspectorValue).foregroundStyle(SuiteColor.secondaryText)
                }
            }
            ChoiceChips(options: options, selected: selected, onSelect: onSelect)
                .disabled(help != nil)
                .help(help ?? "")
                .accessibilityElement(children: .contain)
                .accessibilityLabel(label)
                .suiteControl(id: id, enabled: help == nil, reason: help)
        }
    }

    /// A Size row whose values differ: plain text, still listed as the row's control.
    private func mixed(_ help: String?, id: String) -> some View {
        Text("Mixed")
            .font(SuiteFont.inspectorValue)
            .foregroundStyle(SuiteColor.secondaryText)
            .help(help ?? "")
            .accessibilityLabel("Size")
            .suiteControl(id: id, enabled: help == nil, reason: help)
    }

    /// The Size field's change: kept for the end of a drag, else committed now (Return, focus loss, arrows).
    func sizeChanged(_ size: Double, in scrub: TextSizeScrub) {
        if scrub.dragging { scrub.pending = size } else { commit { $0.size = size } }
    }

    /// The end of a Size drag: commits the last size it reached, once.
    func sizeDragEnded(in scrub: TextSizeScrub) {
        scrub.dragging = false
        guard let size = scrub.pending else { return }
        scrub.pending = nil
        commit { $0.size = size }
    }

    /// One change to the shared style (or, when mixed, the first text layer's) as its own step.
    func commit(_ change: (inout DesignTextStyle) -> Void) {
        var changed = style ?? model.selectedNodes.first { $0.kind == .text }?.textStyle ?? .default
        change(&changed)
        perform(.setStyle(.textStyle(changed)))
        perform(.endEditRun)
    }
}
