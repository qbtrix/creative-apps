// HaloLayerInspector.swift: the selected layer in Halo's inspector: its
// header (`selectedLayerHeader`), the TRANSFORM group, a refusal's caption,
// the LAYER group, then the EASING and TEXT slots. TRANSFORM has one InspectorSliderRow per
// `propertyRows` row (shown value, range, step, unit, decimals; keyed while
// a key sits at the playhead) with a KeyframeButton beside it, or under it
// when the full titles and widest typical values (`widestTypicalText`) don't
// fit beside it, as at the inspector's minimum width: the
// stopwatch sends .toggleAnimation, the diamond .toggleKey. A scrub sends
// .setProperty with the stored value and .endPropertyScrub once it ends.
// Each row is `halo.inspector.row.<raw>` and reads its value as text
// (XCUITest reads values empty otherwise, #262); its button is
// `halo.inspector.key.<raw>`, labelled "Animate <title>" with the key state
// as its value. A refusal naming a row or its button shows under that row;
// any other inspector refusal shows under the group. LAYER has two
// InspectorPickerRows: Parent (`halo.inspector.parent`, None then
// `model.parentChoices`) sends .setParent, and Blend (`halo.inspector.blend`,
// `model.blendChoices`) sends .setBlendMode; each reads its current title as
// its value, and a refusal naming it shows under it. Every control is
// disabled with `model.unavailableHelp(for:)` as help while it can't act.
// With no layer selected nothing shows here (HaloCompositionInspector shows
// the composition instead).
import HaloModel
import SuiteUI
import SwiftUI

struct HaloLayerInspector: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        if let header = model.selectedLayerHeader {
            VStack(alignment: .leading, spacing: 0) {
                InspectorHeader(header.name, details: [header.kind, header.frames, header.parent.map { "Parent: \($0)" } ?? ""])
                    .accessibilityIdentifier("halo.inspector.header")
                InspectorSection("Transform") {
                    // Bars beside their keyframe buttons while every full
                    // title and value fits; else each button under its bar.
                    ViewThatFits(in: .horizontal) {
                        transformRows(stacked: false)
                        transformRows(stacked: true)
                    }
                }
                if let refusal = model.refusal, refusal.control.hasPrefix("halo.inspector"),
                    !HaloProperty.allCases.contains(where: { rowRefusal($0) != nil }),
                    !HaloLayerGroup.owns(refusal)
                {
                    HaloRefusalCaption(refusal: refusal)
                }
                if let layer = model.selectedLayer {
                    HaloLayerGroup(layer: layer, model: model, perform: perform)
                }
                HaloEasingInspector(model: model, perform: perform)
                HaloTextInspector(model: model, perform: perform)
            }
        }
    }

    /// TRANSFORM's rows, each button beside its bar or `stacked` under it.
    private func transformRows(stacked: Bool) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            ForEach(model.propertyRows) { row in
                HaloPropertyRowView(
                    row: row, model: model, refusal: rowRefusal(row.property), stacked: stacked, perform: perform)
            }
        }
    }

    /// The refusal that names `p`'s row or its keyframe button, if any.
    private func rowRefusal(_ p: HaloProperty) -> HaloRefusal? {
        guard let refusal = model.refusal else { return nil }
        let ids = ["halo.inspector.row.\(p.rawValue)", "halo.inspector.key.\(p.rawValue)"]
        return ids.contains(refusal.control) ? refusal : nil
    }
}

/// One TRANSFORM row: the bar, its keyframe button (beside it, or under it
/// when `stacked`) and its refusal's caption. Beside, the bar's ideal width
/// is what its full title and widest typical value need with the value clear
/// of the bar's middle, so ViewThatFits stacks rather than truncate a title
/// or draw the marker over the value.
private struct HaloPropertyRowView: View {
    let row: HaloPropertyRow
    let model: HaloProject
    let refusal: HaloRefusal?
    let stacked: Bool
    let perform: @MainActor (HaloCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if stacked {
                VStack(alignment: .trailing, spacing: SuiteSpacing.xs) {
                    bar
                    key
                }
            } else {
                HStack(spacing: SuiteSpacing.xs) {
                    ZStack {
                        fit.hidden().accessibilityHidden(true)
                        bar
                    }
                    key
                }
            }
            if let refusal {
                HaloRefusalCaption(refusal: refusal)
            }
        }
    }

    /// The property's bar slider.
    private var bar: some View {
        let p = row.property
        let rowHelp = model.unavailableHelp(for: .setProperty(p, row.value))
        return InspectorSliderRow(
            p.title, value: row.shown, in: row.shownRange, step: row.shownStep, unit: p.unit,
            decimals: p.decimals, keyed: row.keyState == .keyedHere,
            onChange: { perform(.setProperty(p, p.stored(fromShown: $0))) },
            onEnd: { perform(.endPropertyScrub) })
            .disabled(rowHelp != nil)
            .help(rowHelp ?? p.title)
            .accessibilityValue(Text(verbatim: row.text))
            .haloControl(id: "halo.inspector.row.\(p.rawValue)", enabled: rowHelp == nil, help: rowHelp)
    }

    /// The property's stopwatch and key diamond.
    private var key: some View {
        let p = row.property
        let keyHelp = model.unavailableHelp(for: .toggleAnimation(p))
        return KeyframeButton(
            p.title, state: Self.keyState(row.keyState),
            onToggle: { perform(.toggleAnimation(p)) },
            onKey: { perform(.toggleKey(p)) })
            .disabled(keyHelp != nil)
            .haloControl(id: "halo.inspector.key.\(p.rawValue)", enabled: keyHelp == nil, help: keyHelp)
    }

    /// The bar's room, never drawn (the bar itself has no ideal width): the
    /// full title, a gap and the widest typical value; and the value twice,
    /// so the value starts past the bar's middle, where the marker sits for
    /// a value mid-range.
    private var fit: some View {
        let p = row.property
        let value = Text(verbatim: p.widestTypicalText).font(SuiteFont.inspectorValue)
        return ZStack {
            HStack(spacing: SuiteSpacing.s) {
                Text(verbatim: p.title).font(SuiteFont.inspectorLabel)
                value
            }
            HStack(spacing: 0) {
                value
                value
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, SuiteSpacing.m)
    }

    /// HaloModel's key state as SuiteUI's, one to one.
    static func keyState(_ state: HaloKeyState) -> KeyState {
        switch state {
        case .notAnimated: .idle
        case .animated: .animated
        case .keyedHere: .keyedHere
        }
    }
}

/// LAYER: the Parent and Blend pickers, each with its refusal's caption.
private struct HaloLayerGroup: View {
    let layer: HaloLayer
    let model: HaloProject
    let perform: @MainActor (HaloCommand) -> Void

    static let parentIDs = ["halo.inspector.parent"]
    static let blendIDs = ["halo.inspector.blend", "halo.inspector.row.blend"]

    /// Whether `refusal` names Parent or Blend, so it shows here.
    static func owns(_ refusal: HaloRefusal) -> Bool {
        (parentIDs + blendIDs).contains(refusal.control)
    }

    var body: some View {
        let parentHelp = model.unavailableHelp(for: .setParent(layer.parentID))
        let blendHelp = model.unavailableHelp(for: .setBlendMode(layer.blendMode))
        let parents = [InspectorOption<String?>(id: nil, title: "None")]
            + model.parentChoices.map { InspectorOption<String?>(id: $0.id, title: $0.name) }
        let blends = model.blendChoices.map { InspectorOption(id: $0.mode, title: $0.title) }
        let parentTitle = parents.first { $0.id == layer.parentID }?.title ?? "None"
        let blendTitle = blends.first { $0.id == layer.blendMode }?.title ?? ""
        InspectorSection("Layer") {
            InspectorPickerRow("Parent", options: parents, selection: layer.parentID) { perform(.setParent($0)) }
                .disabled(parentHelp != nil)
                .help(parentHelp ?? "Parent")
                .accessibilityValue(Text(verbatim: parentTitle))
                .haloControl(id: "halo.inspector.parent", enabled: parentHelp == nil, help: parentHelp)
            if let refusal = refusal(Self.parentIDs) {
                HaloRefusalCaption(refusal: refusal)
            }
            InspectorPickerRow("Blend", options: blends, selection: layer.blendMode) { perform(.setBlendMode($0)) }
                .disabled(blendHelp != nil)
                .help(blendHelp ?? "Blend")
                .accessibilityValue(Text(verbatim: blendTitle))
                .haloControl(id: "halo.inspector.blend", enabled: blendHelp == nil, help: blendHelp)
            if let refusal = refusal(Self.blendIDs) {
                HaloRefusalCaption(refusal: refusal)
            }
        }
    }

    /// The model's refusal when it names one of `ids`.
    private func refusal(_ ids: [String]) -> HaloRefusal? {
        guard let refusal = model.refusal, ids.contains(refusal.control) else { return nil }
        return refusal
    }
}
