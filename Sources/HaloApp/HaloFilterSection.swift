// HaloFilterSection.swift (adjust-everywhere AJ-13): the FILTERS slot of Halo's layer inspector, under STROKE, shown
// only while the selected layer has filters (`shows`), so a layer with none reads as before. Its entry point is
// Layer > Add Filter (HaloAddFilterMenu), SuiteUI's FilterMenu with a submenu per titled group, then the
// adjustments; the same menu closes the section to add another. One row per entry, first run first: its name with
// a hide toggle (eye) and remove, then, for a filter, a slider per FilterSheetDraft slider
// (`halo.inspector.filter.<entry>.<slider>`). A drag's samples share one token, so the Model records one step. A
// row drags onto another to move there. Every gesture is one HaloFilterIntent sent to the window's `haloFilter`
// action (environment and focused scene value), which runs `HaloProject.runFilter` on the selected layer only.
// While `adjustHelp` says why, every control is off with it as the tooltip. Values in, intents out.
import HaloModel
import SuiteUI
import SwiftUI

/// Runs one FILTERS gesture on the selected layer.
typealias HaloFilterAction = @MainActor (HaloFilterIntent) -> Void

extension EnvironmentValues {
    /// The window's filter action; nil outside a window that wires it.
    @Entry var haloFilter: HaloFilterAction?
}

extension FocusedValues {
    /// The focused window's filter action, for Layer > Add Filter.
    @Entry var haloFilter: HaloFilterAction?
}

/// Add Filter: FilterMenu's filters (a submenu per titled group) and adjustments, each from its catalog spec. Off,
/// with the reason as its help, while nothing can be filtered.
struct HaloAddFilterMenu: View {
    let model: HaloProject?
    let run: HaloFilterAction?
    var identifier: String?

    private var state: HaloMenuState { HaloMenuState(project: run == nil ? nil : model) }
    private var help: String? { state.availability("filter.gaussian-blur").why }

    var body: some View {
        Menu("Add Filter", systemImage: "camera.filters") {
            ForEach(FilterMenu.filter, id: \.self) { group in
                if let title = group.title {
                    Menu(title) { ForEach(group.items, id: \.self) { item($0) } }
                } else {
                    ForEach(group.items, id: \.self) { item($0) }
                }
            }
            Divider()
            ForEach(FilterMenu.adjustments, id: \.self) { item($0) }
        }
        .disabled(help != nil)
        .help(help ?? "Add a filter to the selected layer.")
        .accessibilityIdentifier(identifier ?? "halo.menu.add-filter")
    }

    /// One item: its catalog command adds its entry ("filter.sharpen" adds "sharpen").
    private func item(_ item: FilterMenuItem) -> MenuCommand {
        let key = String(item.command.drop { $0 != "." }.dropFirst())
        let title = item.title.hasSuffix("…") ? String(item.title.dropLast()) : item.title
        return MenuCommand(HaloMenuState.spec(item.command), on: state, title: title) { run?(.add(key)) }
    }
}

struct HaloFilterSection: View {
    /// The selected layer's entries, first run first.
    let filters: [HaloLayerFilter]
    /// Why nothing can be filtered; nil while it can.
    let help: String?
    let model: HaloProject
    @Environment(\.haloFilter) private var run
    @State private var drag: String?

    /// Whether FILTERS shows: only for a layer with filters.
    nonisolated static func shows(_ filters: [HaloLayerFilter]) -> Bool { !filters.isEmpty }

    nonisolated static func id(_ entry: String, _ part: String) -> String { "halo.inspector.filter.\(entry).\(part)" }

    var body: some View {
        InspectorSection("Filters") {
            ForEach(Array(filters.enumerated()), id: \.element.id) { index, entry in
                row(entry)
                    .draggable(entry.id)
                    .dropDestination(for: String.self, isEnabled: help == nil) { ids, _ in
                        guard let id = ids.first, id != entry.id else { return }
                        run?(.move(id, to: index))
                    }
            }
            HaloAddFilterMenu(model: model, run: run, identifier: "halo.inspector.filter.add")
        }
    }

    @ViewBuilder private func row(_ entry: HaloLayerFilter) -> some View {
        VStack(spacing: 0) {
            InspectorRow(entry.title) {
                HStack(spacing: SuiteSpacing.xs) {
                    InspectorAction(ToolbarAction(
                        "\(entry.hidden ? "Show" : "Hide") \(entry.title)", systemImage: entry.hidden ? "eye.slash" : "eye",
                        isSelected: entry.hidden, unavailableHelp: help, identifier: Self.id(entry.id, "hide"),
                        isToggle: true
                    ) { run?(.hide(entry.id, !entry.hidden)) }, iconOnly: true, isToggle: true)
                    InspectorAction(ToolbarAction(
                        "Remove \(entry.title)", systemImage: "minus.circle", unavailableHelp: help,
                        identifier: Self.id(entry.id, "remove")
                    ) { run?(.remove(entry.id)) }, iconOnly: true)
                }
            }
            if !entry.values.isEmpty, let draft = FilterSheetDraft(entry.id) {
                ForEach(draft.sliders) { slider in sliderRow(entry, slider) }
            }
        }
    }

    private func sliderRow(_ entry: HaloLayerFilter, _ s: FilterSlider) -> some View {
        let id = Self.id(entry.id, s.id)
        return InspectorSliderRow(
            s.title, value: entry.values[s.id] ?? s.range.lowerBound, in: s.range, step: s.step, unit: s.unit,
            decimals: s.step < 1 ? 1 : 0,
            onChange: { v in
                let token = drag ?? UUID().uuidString
                drag = token
                run?(.value(entry.id, slider: s.id, v, drag: token))
            },
            onEnd: { drag = nil })
            .disabled(help != nil)
            .help(help ?? s.title)
            .haloControl(id: id, enabled: help == nil, help: help)
    }
}
