// HaloLayerInspector.swift: the selected layer in Halo's inspector: its
// header (`selectedLayerHeader`), the TRANSFORM group, a refusal's caption,
// the LAYER group, then the EASING and TEXT slots. TRANSFORM has one InspectorSliderRow per
// `propertyRows` row (shown value, range, step, unit, decimals; keyed while
// a key sits at the playhead) with a KeyframeButton beside it, or under it
// when the full titles and widest typical values (`widestTypicalText`) don't
// fit beside it, as at the inspector's minimum width (HaloBarAndKeyLayout
// picks per row from the width it gets, against `besideWidth`): the
// stopwatch sends .toggleAnimation, the diamond .toggleKey. A scrub shows
// its value in the bar and puts the window's project with it set
// (`setProperty` on a copy, HaloLiveEdit.show) in the window's HaloLiveEdit, so only the bar and
// the viewer's layers re-run per sample; once it ends (a drag, a key, a typed
// value) the row sends .setProperty with the stored value and
// .endPropertyScrub, one step. Hosted without a HaloLiveEdit, each value is
// sent as it comes.
// Each row is `halo.inspector.row.<raw>` and reads its value as text
// (XCUITest reads values empty otherwise, #262); its stopwatch is
// `halo.inspector.key.<raw>`, labelled "Animate <title>" with the key state
// as its value, and its diamond `halo.inspector.key.<raw>.diamond`. A
// refusal naming a row or its stopwatch shows under that row;
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
                    transformRows
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

    /// TRANSFORM's rows, each button beside its bar or under it.
    private var transformRows: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            ForEach(model.propertyRows) { row in
                HaloPropertyRowView(
                    row: row, refusal: rowRefusal(row.property),
                    rowHelp: model.unavailableHelp(for: .setProperty(row.property, row.value)),
                    keyHelp: model.unavailableHelp(for: .toggleAnimation(row.property)), perform: perform
                )
                .equatable()
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

/// One TRANSFORM row: the bar, its keyframe button (beside it from
/// `besideWidth` up, else under it) and its refusal's caption. Its inputs are
/// values (the Model's help strings come from the parent; `perform` is the
/// window's, which always acts on the window's current project, so it is
/// left out of `==`), so a frame that leaves the row as it was skips its body.
struct HaloPropertyRowView: View, Equatable {
    let row: HaloPropertyRow
    let refusal: HaloRefusal?
    /// Why the bar can't act, and why the keyframe button can't; nil while it can.
    let rowHelp: String?
    let keyHelp: String?
    let perform: @MainActor (HaloCommand) -> Void
    /// The bar's shown value while a scrub lasts; nil otherwise.
    @State private var scrubbed: Double?
    @Environment(\.haloLiveEdit) private var live

    #if DEBUG
    /// How many times a row's body ran; HaloWindowPlaybackTests counts playback's.
    static var bodyRuns = 0
    #endif

    nonisolated static func == (a: Self, b: Self) -> Bool {
        a.row == b.row && a.refusal == b.refusal && a.rowHelp == b.rowHelp
            && a.keyHelp == b.keyHelp
    }

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: 0) {
            HaloBarAndKeyLayout(besideWidth: Self.besideWidth, spacing: SuiteSpacing.xs) {
                bar
                key
            }
            if let refusal {
                HaloRefusalCaption(refusal: refusal)
            }
        }
    }

    /// The property's bar slider.
    private var bar: some View {
        let p = row.property
        return InspectorSliderRow(
            p.title, value: scrubbed ?? row.shown, in: row.shownRange, step: row.shownStep, unit: p.unit,
            decimals: p.decimals, keyed: row.keyState == .keyedHere,
            onChange: { scrub(to: $0) },
            onEnd: {
                if live != nil, let scrubbed { perform(.setProperty(p, p.stored(fromShown: scrubbed))) }
                perform(.endPropertyScrub)
                scrubbed = nil
                live?.project = nil
            })
            .disabled(rowHelp != nil)
            .help(rowHelp ?? p.title)
            .accessibilityValue(Text(verbatim: row.text))
            .haloControl(id: "halo.inspector.row.\(p.rawValue)", enabled: rowHelp == nil, help: rowHelp)
    }

    /// One scrub value: the bar shows it and the viewer draws the window's
    /// project with it set; the window gets it at the scrub's end.
    private func scrub(to shown: Double) {
        let p = row.property
        scrubbed = shown
        guard let live else { return perform(.setProperty(p, p.stored(fromShown: shown))) }
        live.show { $0.setProperty(p, to: p.stored(fromShown: shown)) }
    }

    /// The property's stopwatch and key diamond. KeyframeButton sets both
    /// identifiers itself; here they are only listed, the diamond while shown.
    private var key: some View {
        let p = row.property
        let id = "halo.inspector.key.\(p.rawValue)"
        let state = Self.keyState(row.keyState)
        return KeyframeButton(
            p.title, id: id, state: state,
            onToggle: { perform(.toggleAnimation(p)) },
            onKey: { perform(.toggleKey(p)) })
            .disabled(keyHelp != nil)
            .haloControl(id: id, enabled: keyHelp == nil, help: keyHelp, identifies: false)
            .haloControl(
                id: state.diamond == nil ? nil : KeyframeButton.diamondID(id), enabled: keyHelp == nil, help: keyHelp,
                identifies: false)
    }

    /// The width a row needs to put its keyframe button beside its bar: the
    /// widest property's `fit`, the gap and the button's two cells. It
    /// depends on fonts and titles only, so it is measured once.
    @MainActor static let besideWidth: CGFloat =
        (HaloProperty.allCases.map { NSHostingView(rootView: HaloRowFit(property: $0)).fittingSize.width }.max() ?? 0)
        + SuiteSpacing.xs + 2 * SuiteSize.keyframeButton

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

/// A TRANSFORM row's bar and keyframe button: the button beside the bar,
/// trailing, while the row is at least `besideWidth` wide; else under it at
/// the trailing edge. It decides from the width it is given, so a divider
/// drag measures each row once: a ViewThatFits over two copies of the rows,
/// or a geometry observer on them, each doubled every width step's layout.
struct HaloBarAndKeyLayout: Layout {
    let besideWidth: CGFloat
    let spacing: CGFloat

    /// Whether the button sits beside the bar at `width` (nil: ideal, beside).
    func beside(_ width: CGFloat?) -> Bool { (width ?? besideWidth) >= besideWidth }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let key = subviews[1].sizeThatFits(.unspecified)
        let width = proposal.width ?? besideWidth
        if beside(proposal.width) {
            let bar = subviews[0].sizeThatFits(ProposedViewSize(width: max(width - spacing - key.width, 0), height: nil))
            return CGSize(width: width, height: max(bar.height, key.height))
        }
        let bar = subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: width, height: bar.height + spacing + key.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let key = subviews[1].sizeThatFits(.unspecified)
        if beside(bounds.width) {
            let bar = ProposedViewSize(width: max(bounds.width - spacing - key.width, 0), height: nil)
            subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: bar)
            subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: ProposedViewSize(key))
        } else {
            let bar = subviews[0].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: nil))
            subviews[1].place(
                at: CGPoint(x: bounds.maxX, y: bounds.minY + bar.height + spacing), anchor: .topTrailing,
                proposal: ProposedViewSize(key))
        }
    }
}

/// A bar's room, never drawn (the bar itself has no ideal width): the full
/// title, a gap and the widest typical value; and the value twice, so the
/// value starts past the bar's middle, where the marker sits for a value
/// mid-range. HaloPropertyRowView.besideWidth measures it.
struct HaloRowFit: View {
    let property: HaloProperty

    var body: some View {
        let value = Text(verbatim: property.widestTypicalText).font(SuiteFont.inspectorValue)
        ZStack {
            HStack(spacing: SuiteSpacing.s) {
                Text(verbatim: property.title).font(SuiteFont.inspectorLabel)
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
}
