// GradientEditor.swift (gradient-fill GF-3): the one gradient editor every app shows in its paint section (packet
// docs/blueprints/suiteui/features/gradient-fill.md). It never edits a document: each gesture is one kernel
// `GradientIntent` sent through `onIntent`, which the app runs as its fill command, and the app's live fill comes
// back in, a solid one included. Rows: the Solid / Linear / Radial switch (a segmented Picker, its segments
// `<typeID>.<type>`, `suite.gradient.type.<type>` by default; while `typeHelp` says why it can't act it is off and that
// reason shows under it), the stop bar (`suite.gradient.bar`, its handles `suite.gradient.stop.<n>`, inset half a
// handle each side by the kernel's `GradientBar`), the selected stop's colour (the suite colour row labelled
// "Stop 2 · 50%" with its opacity, live through a drag, hex field `suite.gradient.color`), under the bar the selected
// stop's Location in percent (`suite.gradient.location`, its samples one move under one token) and, for a linear fill
// unless `showsAngle` is false, the angle bar (`suite.gradient.angle`). The switch is its own view, `GradientTypeSwitch`, so
// an app shows the same one over a solid fill's colour row. The bar's gesture math is `GradientBarDrag`: a click adds a stop, a drag moves one under
// one drag token, a drag 40 pt off removes it; arrows nudge the selected stop 1% and Delete removes it. A colour-panel
// session and an angle scrub each carry one token too, so the app folds each gesture into one undo step. Where a stop
// lands after an add or a move comes from `GradientRules`, so the selection follows it.
import Foundation
import SuiteKernel
import SwiftUI

public struct GradientEditor: View {
    private let fill: Fill
    /// The box the fill's points are in.
    private let box: Rect
    /// False hides the angle row (a tool whose drag sets the line, Photo's Gradient tool).
    private let showsAngle: Bool
    /// The fill types the switch offers.
    private let types: [FillType]
    /// The switch's identifier prefix: each segment is `<typeID>.<type>`.
    private let typePrefix: String
    /// Why the switch can't act now, shown under it; nil while it can.
    private let typeHelp: String?
    /// Called once per gesture sample with its intent.
    private let onIntent: @MainActor (GradientIntent) -> Void
    @State private var selected = 0
    @State private var drag: GradientBarDrag?
    @State private var colorToken: String?
    @State private var angleToken: String?
    @State private var locationToken: String?
    /// True after a remove the two-stop rule refused, until the next gesture.
    @State private var refused = false
    @FocusState private var barFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    /// The bar's height, its handles' size, and the distance a click may miss a handle by.
    nonisolated static let barHeight: CGFloat = 20, handleSize: CGFloat = 12
    /// The selected handle's ring, wider than the others' so the picked stop reads at a glance.
    static let ringWidth: CGFloat = 1, selectedRingWidth: CGFloat = 3

    /// The identifier of `type`'s segment under the switch's prefix.
    nonisolated static func typeID(_ type: FillType, in prefix: String) -> String { GradientTypeSwitch.typeID(type, in: prefix) }

    /// The bar and its handles dim with the rest of the rows while the editor is off.
    nonisolated static func barOpacity(enabled: Bool) -> Double { enabled ? 1 : SuiteColor.disabledOpacity }

    /// `showsAngle: false` for a tool whose drag sets the line (Photo's Gradient tool); `types` limits the switch (the
    /// three paints by default); `typeID` prefixes its segments' identifiers; `typeHelp` turns it off and says why.
    public init(fill: Fill, box: Rect, showsAngle: Bool = true, types: [FillType] = FillType.allCases,
                typeID: String = GradientTypeSwitch.defaultID, typeHelp: String? = nil,
                onIntent: @escaping @MainActor (GradientIntent) -> Void) {
        self.fill = fill
        self.box = box
        self.showsAngle = showsAngle
        self.types = types
        self.typePrefix = typeID
        self.typeHelp = typeHelp
        self.onIntent = onIntent
    }

    /// The editor with stop `selected` picked and, when `refused`, the two-stop help showing: the snapshots' states.
    init(fill: Fill, box: Rect, selected: Int, refused: Bool, onIntent: @escaping @MainActor (GradientIntent) -> Void) {
        self.init(fill: fill, box: box, onIntent: onIntent)
        _selected = State(initialValue: selected)
        _refused = State(initialValue: refused)
    }

    /// Whether the angle row shows: a linear fill, in an editor that shows it.
    nonisolated static func showsAngleRow(_ fill: Fill, showsAngle: Bool) -> Bool { showsAngle && GradientRules.type(of: fill) == .linear }

    private var type: FillType { GradientRules.type(of: fill) }
    /// The selected stop, kept inside the fill's stops (0 for a solid).
    private var index: Int { min(max(selected, 0), max(fill.stops.count - 1, 0)) }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            if types.count > 1 {
                GradientTypeSwitch(type: type, types: types, typeID: typePrefix, help: typeHelp) { send(.type($0)) }
            }
            if type != .solid {
                bar
                location
            }
            InspectorColorWellRow(GradientEditorText.selectedStop(index, of: fill), color: GradientEditorText.hex(stopColor),
                                  opacity: stopColor.a, onChange: recolor) {
                colorToken = nil
            }
            .hexIdentifier("suite.gradient.color")
            if Self.showsAngleRow(fill, showsAngle: showsAngle) {
                InspectorSliderRow("Angle", value: GradientRules.angle(of: fill) ?? 0, in: 0...359, step: 1, unit: "°", decimals: 0) { degrees in
                    let token = angleToken ?? GradientBarDrag.newToken()
                    angleToken = token
                    send(.angle(degrees, drag: token))
                } onEnd: {
                    angleToken = nil
                }
                .accessibilityIdentifier("suite.gradient.angle")
            }
            if refused { InspectorNote(GradientRules.stopHelp, kind: .secondary, identifier: "suite.gradient.help") }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.gradient")
    }

    /// The selected stop's Location, 0...100%: each sample moves it under the row's token, so a scrub is one undo step
    /// and the selection follows the stop when it passes another.
    private var location: some View {
        InspectorSliderRow("Location", value: GradientEditorText.percent(stopOffset), in: 0...100, step: 1, unit: "%", decimals: 0) { percent in
            let stop = index, offset = GradientEditorText.offset(percent: percent)
            let token = locationToken ?? GradientBarDrag.newToken()
            locationToken = token
            selected = GradientRules.movingStop(fill, index: stop, to: offset).index
            send(.move(index: stop, offset: offset, drag: token))
        } onEnd: {
            locationToken = nil
        }
        .accessibilityIdentifier("suite.gradient.location")
    }

    /// The selected stop's offset; a solid reads its own colour at 0.
    private var stopOffset: Double { fill.stops.indices.contains(index) ? fill.stops[index].offset : 0 }

    /// The stop bar: the stops left to right with a handle under each, one drag gesture over it all.
    private var bar: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    let rect = CGRect(x: Self.handleSize / 2, y: 0, width: max(size.width - Self.handleSize, 0), height: Self.barHeight)
                    let unit = Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)
                    let flat = Fill.linear(stops: fill.stops, start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))
                    context.fill(SwiftUI.Path(roundedRect: rect, cornerRadius: SuiteRadius.field), with: flat.shading(in: rect, box: unit))
                    context.stroke(SwiftUI.Path(roundedRect: rect, cornerRadius: SuiteRadius.field), with: .color(SuiteColor.outline), lineWidth: 1)
                }
                ForEach(fill.stops.indices, id: \.self) { stop in handle(stop, width: width) }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                if drag == nil { begin(at: value.startLocation, width: width) }
                if let intent = drag?.changed(to: value.location, fill: fill) { send(intent, keepRefusal: true) }
            }.onEnded { value in
                guard var current = drag else { return }
                let intent = current.ended(at: value.location, fill: fill)
                refused = current.refused
                drag = nil
                if case .add(let offset) = intent, let added = GradientRules.addingStop(fill, at: offset) { selected = added.index }
                if let intent { send(intent, keepRefusal: true) }
                barFocused = true
            })
        }
        .frame(height: Self.barHeight + Self.handleSize / 2 + SuiteSpacing.xs)
        .opacity(Self.barOpacity(enabled: isEnabled))
        .focusable()
        .focused($barFocused)
        .onKeyPress(.leftArrow) { nudge(-0.01) }
        .onKeyPress(.rightArrow) { nudge(0.01) }
        .onKeyPress(.delete) { removeSelected() }
        .onKeyPress(.deleteForward) { removeSelected() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Gradient stops")
        .accessibilityIdentifier("suite.gradient.bar")
        .help("Click to add a stop, drag one to move it, drag it off the bar to remove it.")
        .suiteControl(id: "suite.gradient.bar", enabled: true, reason: nil, identifies: false)
    }

    /// One stop's handle: its colour in a ring, under the bar at its offset, a wide accent ring while selected.
    private func handle(_ stop: Int, width: CGFloat) -> some View {
        let offset = fill.stops[stop].offset
        return Circle()
            .fill(fill.stops[stop].color.swiftUI)
            .overlay(Circle().strokeBorder(stop == index ? SuiteColor.accent : SuiteColor.outline,
                                           lineWidth: stop == index ? Self.selectedRingWidth : Self.ringWidth))
            .frame(width: Self.handleSize, height: Self.handleSize)
            .position(x: GradientBarDrag.x(of: offset, width: width), y: Self.barHeight)
            .accessibilityElement()
            .accessibilityLabel(GradientEditorText.stop(stop, of: fill))
            .accessibilityAddTraits(stop == index ? .isSelected : [])
            .accessibilityIdentifier("suite.gradient.stop.\(stop)")
            .accessibilityAdjustableAction { direction in
                selected = stop
                _ = nudge(direction == .increment ? 0.01 : -0.01)
            }
            .help(fill.stops.count <= 2 ? GradientRules.stopHelp : "Drag off the bar to remove this stop.")
    }

    private func begin(at point: CGPoint, width: CGFloat) {
        let next = GradientBarDrag(at: point, width: width, fill: fill, token: GradientBarDrag.newToken())
        if let stop = next.stop { selected = stop }
        drag = next
    }

    /// Moves the selected stop by `step`, one undo step per press.
    private func nudge(_ step: Double) -> KeyPress.Result {
        guard type != .solid, fill.stops.indices.contains(index) else { return .ignored }
        let offset = min(max(fill.stops[index].offset + step, 0), 1)
        selected = GradientRules.movingStop(fill, index: index, to: offset).index
        send(.move(index: index, offset: offset, drag: GradientBarDrag.newToken()))
        return .handled
    }

    private func removeSelected() -> KeyPress.Result {
        guard type != .solid else { return .ignored }
        guard fill.stops.count > 2 else { refused = true; return .handled }
        send(.remove(index: index))
        selected = max(index - 1, 0)
        return .handled
    }

    /// The selected stop's colour (a solid's own).
    private var stopColor: FillColor { GradientRules.color(of: fill, at: stopOffset) }

    /// The colour row's pick: the selected stop's colour and opacity, under the session's token.
    private func recolor(_ hex: HexColor, _ alpha: Double) {
        let token = colorToken ?? GradientBarDrag.newToken()
        colorToken = token
        send(.color(index: index, GradientEditorText.fillColor(hex, alpha: alpha), drag: token))
    }

    private func send(_ intent: GradientIntent, keepRefusal: Bool = false) {
        if !keepRefusal { refused = false }
        if case .move(let stop, let offset, _) = intent, drag != nil {
            selected = GradientRules.movingStop(fill, index: stop, to: offset).index
        }
        onIntent(intent)
    }
}

/// The Solid / Linear / Radial switch: a system segmented Picker, its segments `<typeID>.<type>`, off with its reason
/// under it (`<typeID>.help`) while `help` is set. A nil `type` (a selection whose fills differ) picks no segment.
/// GradientEditor shows it over a gradient; an app shows it over a solid fill's own colour row.
public struct GradientTypeSwitch: View {
    /// The default identifier prefix.
    public static let defaultID = "suite.gradient.type"
    private let type: FillType?, types: [FillType], prefix: String, help: String?
    private let onPick: @MainActor (FillType) -> Void

    public init(type: FillType?, types: [FillType] = FillType.allCases, typeID: String = Self.defaultID, help: String? = nil,
                onPick: @escaping @MainActor (FillType) -> Void) {
        (self.type, self.types, self.prefix, self.help, self.onPick) = (type, types, typeID, help, onPick)
    }

    /// The identifier of `type`'s segment under `prefix`.
    public nonisolated static func typeID(_ type: FillType, in prefix: String) -> String { "\(prefix).\(type.rawValue)" }
    /// The identifier of the note that says why the switch is off.
    public nonisolated static func helpID(in prefix: String) -> String { "\(prefix).help" }

    public var body: some View {
        Picker("Fill type", selection: Binding<FillType?>(get: { type }, set: { picked in
            if let picked, picked != type { onPick(picked) }
        })) {
            ForEach(types, id: \.self) { option in
                Text(GradientEditorText.type(option)).tag(FillType?.some(option))
                    .accessibilityIdentifier(Self.typeID(option, in: prefix))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .disabled(help != nil)
        .help(help ?? "Fill type")
        .suiteControl(id: prefix, enabled: help == nil, reason: help, identifies: false)
        if let help { InspectorNote(help, kind: .secondary, identifier: Self.helpID(in: prefix)) }
    }
}

/// The stop bar's gesture as intents, pure so tests drive it. Points are in the bar's row, `width` wide, its offsets
/// inset half a handle each side (`GradientBar`). A press on a handle picks its stop, a press elsewhere is
/// an add on release; a horizontal drag moves the stop under one token (its index following re-sorts), and a release
/// more than `removeDistance` off the bar removes it, or is refused with two stops.
struct GradientBarDrag: Equatable {
    static let removeDistance: CGFloat = 40, hitRadius: CGFloat = 8, slop: CGFloat = 3

    let width: CGFloat
    let start: CGPoint
    let token: String
    /// The stop under the press, following it through moves; nil for a press on the bar between stops.
    private(set) var stop: Int?
    private(set) var lastOffset: Double?
    /// True when the release would have removed one of two stops.
    private(set) var refused = false

    init(at point: CGPoint, width: CGFloat, fill: Fill, token: String) {
        (self.width, start, self.token) = (width, point, token)
        let hits = fill.stops.indices.map { ($0, abs(Self.x(of: fill.stops[$0].offset, width: width) - point.x)) }
            .filter { $0.1 <= Self.hitRadius }
        stop = hits.min { $0.1 < $1.1 }?.0
        lastOffset = stop.map { fill.stops[$0].offset }
    }

    /// A fresh drag token.
    static func newToken() -> String { String(UUID().uuidString.prefix(8)) }

    /// Where the handle of a stop at `offset` is centred in a row `width` wide.
    static func x(of offset: Double, width: CGFloat) -> CGFloat {
        CGFloat(GradientBar.x(of: offset, width: Double(width), handle: Double(GradientEditor.handleSize)))
    }

    private func offset(at x: CGFloat) -> Double {
        GradientBar.offset(at: Double(x), width: Double(width), handle: Double(GradientEditor.handleSize))
    }
    private func isOff(_ point: CGPoint) -> Bool { abs(point.y - start.y) > Self.removeDistance }

    /// The intent for a pointer sample: a move of the held stop when its offset changed and it is on the bar.
    mutating func changed(to point: CGPoint, fill: Fill) -> GradientIntent? {
        guard let held = stop, !isOff(point) else { return nil }
        let offset = offset(at: point.x)
        guard offset != lastOffset else { return nil }
        lastOffset = offset
        stop = GradientRules.movingStop(fill, index: held, to: offset).index
        return .move(index: held, offset: offset, drag: token)
    }

    /// The intent for the release: an add for a click on the bar, a remove for a stop dropped off it.
    mutating func ended(at point: CGPoint, fill: Fill) -> GradientIntent? {
        guard let held = stop else {
            let still = abs(point.x - start.x) <= Self.slop && abs(point.y - start.y) <= Self.slop
            return still ? .add(offset: offset(at: start.x)) : nil
        }
        guard isOff(point) else { return nil }
        guard fill.stops.count > 2 else { refused = true; return nil }
        return .remove(index: held)
    }
}

/// The editor's texts.
enum GradientEditorText {
    /// "Solid", "Linear" or "Radial".
    static func type(_ type: FillType) -> String { type.rawValue.capitalized }

    /// The colour row's label: "Stop 2 · 50%" for the selected stop, "Color" for a solid.
    static func selectedStop(_ index: Int, of fill: Fill) -> String { GradientBar.stopLabel(index, of: fill) }

    /// The Location row's value for a stop at `offset`: 0.5 is 50.
    static func percent(_ offset: Double) -> Double { min(max(offset, 0), 1) * 100 }

    /// The stop offset for the Location row's `percent`, clamped to 0...1.
    static func offset(percent: Double) -> Double { percent.isFinite ? min(max(percent / 100, 0), 1) : 0 }

    /// The Location row's text for a stop at `offset`: "50%".
    static func location(_ offset: Double) -> String { NumericInput.text(percent(offset), decimals: 0, unit: "%") }

    /// "45°", rounded to a whole degree; "–" when there is no angle.
    static func angle(_ degrees: Double?) -> String {
        guard let degrees, degrees.isFinite else { return "–" }
        return NumericInput.text(degrees, decimals: 0, unit: "°")
    }

    /// What VoiceOver reads for stop `index`: "Stop 2 of 3, 50 percent, red".
    static func stop(_ index: Int, of fill: Fill) -> String {
        guard fill.stops.indices.contains(index) else { return "" }
        let stop = fill.stops[index]
        return "Stop \(index + 1) of \(fill.stops.count), \(Int((stop.offset * 100).rounded())) percent, \(colorName(stop.color))"
    }

    /// A colour's plain name by hue: grey, black or white when it has little colour.
    static func colorName(_ color: FillColor) -> String {
        let (high, low) = (max(color.r, color.g, color.b), min(color.r, color.g, color.b))
        guard high - low > 0.1 else { return high < 0.15 ? "black" : high > 0.9 ? "white" : "grey" }
        let span = high - low
        var hue = high == color.r ? (color.g - color.b) / span : high == color.g ? 2 + (color.b - color.r) / span : 4 + (color.r - color.g) / span
        hue = (hue * 60 + 360).truncatingRemainder(dividingBy: 360)
        let names: [(Double, String)] = [(15, "red"), (45, "orange"), (70, "yellow"), (165, "green"), (195, "cyan"),
                                         (255, "blue"), (290, "purple"), (345, "pink")]
        return names.first { hue < $0.0 }?.1 ?? "red"
    }

    /// A colour row's pick as a fill colour: its sRGB channels and `alpha`.
    static func fillColor(_ hex: HexColor, alpha: Double) -> FillColor {
        let picked = hex.resolved
        return FillColor(r: Double(picked.red), g: Double(picked.green), b: Double(picked.blue), a: alpha)
    }

    /// The colour row's 8-bit colour for `color` (its alpha goes to the row's opacity).
    static func hex(_ color: FillColor) -> HexColor {
        HexColor(SwiftUI.Color.Resolved(red: Float(color.r), green: Float(color.g), blue: Float(color.b)))
    }
}
