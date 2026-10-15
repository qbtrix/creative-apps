// HaloLayerInspector.swift: the selected layer in Halo's inspector: its
// header (`selectedLayerHeader`), the TRANSFORM group, a refusal's caption,
// then the EASING and TEXT slots. TRANSFORM has one InspectorSliderRow per
// `propertyRows` row (shown value, range, step, unit, decimals; keyed while
// a key sits at the playhead) with a KeyframeButton beside it: the
// stopwatch sends .toggleAnimation, the diamond .toggleKey. A scrub sends
// .setProperty with the stored value and .endPropertyScrub once it ends.
// Each row is `halo.inspector.row.<raw>` and reads its value as text
// (XCUITest reads values empty otherwise, #262); its button is
// `halo.inspector.key.<raw>`, labelled "Animate <title>" with the key state
// as its value. A refusal naming a row or its button shows under that row;
// any other inspector refusal shows under the group. Every control is
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
                    !HaloProperty.allCases.contains(where: { rowRefusal($0) != nil })
                {
                    HaloRefusalCaption(refusal: refusal)
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
