// FilterSheet.swift (adjust-everywhere AJ-3): the sheet every app shows for a
// filter or Black & White…: a slider per value from the kind's range and start,
// Preview, Cancel and OK (the kind's catalog command, off with its reason), in
// SuiteSheet with an InspectorSliderRow per value (#5789). The
// host keeps the FilterSheetDraft; OK emits one intent, Cancel nothing.
// FilterMenu lists the menu items. Controls carry `suite.filter.*` identifiers.
import SuiteImaging
import SuiteKernel
import SwiftUI

/// What the sheet's OK runs: a filter on the selected layer, or a kind set on the picture.
public enum FilterSheetIntent: Hashable, Sendable {
    case filter(ImagingFilter)
    case kind(ImagingKind)
}

/// One of the sheet's sliders: a value's name, range, step and unit.
public struct FilterSlider: Hashable, Sendable, Identifiable {
    public let id, title: String
    public let range: ClosedRange<Double>
    public let step: Double
    public let unit: String
}

/// The sheet's choices while it is open.
public struct FilterSheetDraft: Hashable, Sendable {
    /// The filter's id, or "black-and-white".
    public let id: String
    public let title: String
    public let sliders: [FilterSlider]
    public private(set) var values: [String: Double]
    public private(set) var preview = true
    /// Add Noise's grey-only noise.
    public private(set) var monochrome = false
    private var seed: UInt64 = 0

    /// The sheet's two buttons.
    public enum Choice: Sendable { case ok, cancel }

    /// The draft at `id`'s starting values; nil for a kind with nothing to set (Invert) or an unknown id.
    public init?(_ id: String) {
        func s(_ key: String, _ title: String, _ r: ClosedRange<Double>, _ unit: String, _ step: Double = 1) -> FilterSlider {
            FilterSlider(id: key, title: title, range: r, step: step, unit: unit)
        }
        let start: [(FilterSlider, Double)]
        if id == "black-and-white" {
            let w = GrayWeights.neutral
            start = [("red", "Reds", w.red), ("yellow", "Yellows", w.yellow), ("green", "Greens", w.green),
                     ("cyan", "Cyans", w.cyan), ("blue", "Blues", w.blue), ("magenta", "Magentas", w.magenta)]
                .map { (s($0.0, $0.1, GrayWeights.range, "%"), $0.2) }
            title = ImagingKind.blackAndWhite(w).title
        } else {
            guard let f = ImagingFilter.defaults(id) else { return nil }
            title = f.title
            switch f {
            case .gaussianBlur(let r): start = [(s("radius", "Radius", ImagingFilter.blurRadius, "px", 0.1), r)]
            case .motionBlur(let a, let d):
                start = [(s("degrees", "Angle", ImagingFilter.motionDegrees, "°"), a),
                         (s("distance", "Distance", ImagingFilter.motionDistance, "px"), d)]
            case .sharpen(let a, let r, let t):
                start = [(s("amount", "Amount", ImagingFilter.sharpenAmount, "%"), a),
                         (s("radius", "Radius", ImagingFilter.sharpenRadius, "px", 0.1), r),
                         (s("threshold", "Threshold", ImagingFilter.sharpenThreshold, "levels"), t)]
            case .reduceNoise(let st, let d):
                start = [(s("strength", "Strength", ImagingFilter.percent, "%"), st),
                         (s("detail", "Preserve Details", ImagingFilter.percent, "%"), d)]
            case .addNoise(let a, let m, let seed):
                start = [(s("amount", "Amount", ImagingFilter.percent, "%"), a)]
                (monochrome, self.seed) = (m, seed)
            }
        }
        self.id = id
        sliders = start.map(\.0)
        values = Dictionary(uniqueKeysWithValues: start.map { ($0.0.id, $0.1) })
    }

    /// The catalog command OK runs.
    public var command: String { id == "black-and-white" ? "adjust.black-and-white" : "filter.\(id)" }

    public func value(_ slider: String) -> Double { values[slider] ?? 0 }

    /// Sets `slider` to `v`, snapped to its step and clamped to its range; an unknown slider changes nothing.
    public mutating func set(_ slider: String, to v: Double) {
        guard let s = sliders.first(where: { $0.id == slider }), v.isFinite else { return }
        let per = s.step > 0 && s.step < 1 ? (1 / s.step).rounded() : 1
        values[slider] = min(max((v * per).rounded() / per, s.range.lowerBound), s.range.upperBound)
    }

    public mutating func setPreview(_ on: Bool) { preview = on }
    public mutating func setMonochrome(_ on: Bool) { monochrome = on }

    /// What `button` emits: OK the one intent with the values, Cancel nothing.
    public func result(_ button: Choice) -> FilterSheetIntent? {
        guard button == .ok else { return nil }
        let v = value
        switch id {
        case "black-and-white":
            return .kind(.blackAndWhite(GrayWeights(red: v("red"), yellow: v("yellow"), green: v("green"),
                                                    cyan: v("cyan"), blue: v("blue"), magenta: v("magenta"))))
        case "gaussian-blur": return .filter(.gaussianBlur(radius: v("radius")))
        case "motion-blur": return .filter(.motionBlur(degrees: v("degrees"), distance: v("distance")))
        case "sharpen": return .filter(.sharpen(amount: v("amount"), radius: v("radius"), threshold: v("threshold")))
        case "reduce-noise": return .filter(.reduceNoise(strength: v("strength"), detail: v("detail")))
        default: return .filter(.addNoise(amount: v("amount"), monochrome: monochrome, seed: seed))
        }
    }
}

/// A Filter or Adjustments menu item: its catalog command, its title, and the sheet it opens (nil runs at once).
public struct FilterMenuItem: Hashable, Sendable {
    public let command, title: String
    public let sheet: String?
}

/// A submenu of the Filter menu; a nil title puts its items at the top level.
public struct FilterMenuGroup: Hashable, Sendable {
    public let title: String?
    public let items: [FilterMenuItem]
}

/// The Filter menu and Image > Adjustments.
public enum FilterMenu {
    static func item(_ id: String, _ t: String) -> FilterMenuItem { FilterMenuItem(command: "filter.\(id)", title: "\(t)…", sheet: id) }

    public static let filter = [
        FilterMenuGroup(title: "Blur", items: [item("gaussian-blur", "Gaussian Blur"), item("motion-blur", "Motion Blur")]),
        FilterMenuGroup(title: nil, items: [item("sharpen", "Sharpen")]),
        FilterMenuGroup(title: "Noise", items: [item("reduce-noise", "Reduce Noise"), item("add-noise", "Add Noise")]),
    ]

    public static let adjustments = [
        FilterMenuItem(command: "adjust.black-and-white", title: "Black & White…", sheet: "black-and-white"),
        FilterMenuItem(command: "adjust.invert", title: "Invert", sheet: nil),
    ]

    public static var all: [FilterMenuItem] { filter.flatMap(\.items) + adjustments }
}

public struct FilterSheet<Target: AdjustTarget>: View {
    let draft: FilterSheetDraft
    /// What the command's availability reads.
    let target: Target
    let onDraft: @MainActor (FilterSheetDraft) -> Void
    let onOK: @MainActor (FilterSheetIntent) -> Void
    let onCancel: @MainActor () -> Void

    public init(
        draft: FilterSheetDraft, target: Target, onDraft: @escaping @MainActor (FilterSheetDraft) -> Void = { _ in },
        onOK: @escaping @MainActor (FilterSheetIntent) -> Void = { _ in }, onCancel: @escaping @MainActor () -> Void = {}
    ) {
        (self.draft, self.target, self.onDraft, self.onOK, self.onCancel) = (draft, target, onDraft, onOK, onCancel)
    }

    private func change(_ edit: (inout FilterSheetDraft) -> Void) { var next = draft; edit(&next); onDraft(next) }

    public var body: some View {
        SuiteSheet(
            draft.title, width: SuiteSize.inspectorWidth.max, cancelID: "suite.filter.cancel", onCancel: onCancel,
            action: ok, actionID: "suite.filter.ok"
        ) {
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                ForEach(draft.sliders) { s in
                    InspectorSliderRow(
                        s.title, value: draft.value(s.id), in: s.range, step: s.step, unit: s.unit,
                        decimals: s.step < 1 ? 1 : 0, onChange: { v in change { $0.set(s.id, to: v) } })
                    .accessibilityIdentifier("suite.filter.slider.\(s.id)")
                }
                if draft.id == "add-noise" {
                    Toggle("Monochromatic", isOn: Binding(get: { draft.monochrome }, set: { on in change { $0.setMonochrome(on) } }))
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("suite.filter.monochrome")
                }
                Toggle("Preview", isOn: Binding(get: { draft.preview }, set: { on in change { $0.setPreview(on) } }))
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("suite.filter.preview")
            }
        }
    }

    /// OK: the draft's catalog command on the target, so the command's availability decides it.
    var ok: MenuCommand {
        let perform: @MainActor () -> Void = { if let intent = draft.result(.ok) { onOK(intent) } }
        guard let spec = AdjustCommands.specs(Target.self).first(where: { $0.id == draft.command }) else {
            return MenuCommand("OK", help: "OK: \(draft.title) has no command.", isEnabled: false, perform: {})
        }
        return MenuCommand(spec, on: target, title: "OK", perform: perform)
    }
}
