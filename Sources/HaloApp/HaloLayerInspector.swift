// HaloLayerInspector.swift: the selected layer in Halo's inspector: its
// header (`selectedLayerHeader`), the TRANSFORM group, a refusal's caption,
// the LAYER group, then the EASING and TEXT slots. TRANSFORM has one InspectorSliderRow per
// `propertyRows` row (shown value, range, step, unit, decimals; keyed while
// a key sits at the playhead) with a KeyframeButton beside it: the
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
                    ForEach(model.propertyRows) { row in
                        HaloPropertyRowView(
                            row: row, model: model, refusal: rowRefusal(row.property), perform: perform)
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

    /// The refusal that names `p`'s row or its keyframe button, if any.
    private func rowRefusal(_ p: HaloProperty) -> HaloRefusal? {
        guard let refusal = model.refusal else { return nil }
        let ids = ["halo.inspector.row.\(p.rawValue)", "halo.inspector.key.\(p.rawValue)"]
        return ids.contains(refusal.control) ? refusal : nil
    }
}

/// One TRANSFORM row: the bar, its keyframe button and its refusal's caption.
private struct HaloPropertyRowView: View {
    let row: HaloPropertyRow
    let model: HaloProject
    let refusal: HaloRefusal?
    let perform: @MainActor (HaloCommand) -> Void

    var body: some View {
        let p = row.property
        let rowHelp = model.unavailableHelp(for: .setProperty(p, row.value))
        let keyHelp = model.unavailableHelp(for: .toggleAnimation(p))
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: SuiteSpacing.xs) {
                InspectorSliderRow(
                    p.title, value: row.shown, in: row.shownRange, step: row.shownStep, unit: p.unit,
                    decimals: p.decimals, keyed: row.keyState == .keyedHere,
                    onChange: { perform(.setProperty(p, p.stored(fromShown: $0))) },
                    onEnd: { perform(.endPropertyScrub) })
                    .disabled(rowHelp != nil)
                    .help(rowHelp ?? p.title)
                    .accessibilityValue(Text(verbatim: row.text))
                    .haloControl(id: "halo.inspector.row.\(p.rawValue)", enabled: rowHelp == nil, help: rowHelp)
                KeyframeButton(
                    p.title, state: Self.keyState(row.keyState),
                    onToggle: { perform(.toggleAnimation(p)) },
                    onKey: { perform(.toggleKey(p)) })
                    .disabled(keyHelp != nil)
                    .haloControl(id: "halo.inspector.key.\(p.rawValue)", enabled: keyHelp == nil, help: keyHelp)
            }
            if let refusal {
                HaloRefusalCaption(refusal: refusal)
            }
        }
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
