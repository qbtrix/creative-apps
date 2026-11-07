// TransformRows.swift (transform-tools TT-3): the inspector's X, Y, W, H and
// Rotation rows for the selection's TransformBox, and Flip Horizontal and
// Flip Vertical. X, Y, W and H are exact-number fields (whole document
// points), Rotation a bar slider in whole degrees that reads "Mixed" for
// several items' turns; each clamps to its range, and typed text that isn't a
// number shows the range as help. Each edit asks `onIntent` for exactly one
// TransformIntent: `.set` with the box moved, or resized by TransformRules'
// scale about its left (W) or top (H) side as a handle drag does, `.rotate`
// by the difference; one drag shares one token, so the host makes it one undo
// step. With several turns ("Mixed") the row reads "Rotate By": a typed value
// turns each item by that much more (the kernel has no per-item absolute turn).
// A "Flip" label leads the icon-only flips.
// With no selection, or `help`, every control is disabled and says why;
// `flipHelp` disables the flips alone. Identifiers `suite.transform.<row>`,
// `suite.transform.flip-horizontal` and `suite.transform.flip-vertical`.
// `FlipDirection.title` and `systemImage` are the flips' one name and symbol
// (Apple's mirror symbols), shared by every inspector and menu that flips.
import Foundation
import SuiteKernel
import SwiftUI

/// One of the five transform rows, its identifier's last part.
public enum TransformRow: String, CaseIterable, Sendable { case x, y, w, h, rotation }

/// X, Y, W, H, Rotation and the two flip buttons for the selection; `nil` shows the rows disabled with `help`.
public struct TransformRows: View {
    private let selection: TransformBox?
    private let help: String?
    private let flipHelp: String?
    private let rotationMixed: Bool
    private let onIntent: @MainActor (TransformIntent) -> Void
    @State private var drag: String?
    /// How far this gesture has already turned a Mixed selection, so a drag turns by the change.
    @State private var turned = 0.0

    /// `selection` is the box the rows read; `help` says why it can't transform, `flipHelp` why it can't mirror.
    /// `rotationMixed` reads Rotation as "Mixed" (several items' turns). `onIntent` gets each edit the rows ask for.
    public init(selection: TransformBox?, help: String?, flipHelp: String?, rotationMixed: Bool = false,
                onIntent: @escaping @MainActor (TransformIntent) -> Void) {
        self.selection = selection
        self.help = help
        self.flipHelp = flipHelp
        self.rotationMixed = rotationMixed
        self.onIntent = onIntent
    }

    public var body: some View {
        let reason = Self.reason(selection: selection, help: help)
        let item = selection ?? TransformBox(box: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1))
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            ForEach([TransformRow.x, .y, .w, .h], id: \.self) { row in
                InspectorRow(row.rawValue.uppercased()) {
                    ScrubField(row.rawValue.uppercased(), value: Self.value(row, of: item), in: Self.range(row),
                               decimals: 0, onChange: { edit(row, to: $0) }, onEnd: { drag = nil })
                        .suiteControl(id: "suite.transform.\(row.rawValue)", enabled: reason == nil, reason: reason)
                }
            }
            InspectorSliderRow(Self.rotationLabel(mixed: rotationMixed), value: Self.value(.rotation, of: item), in: Self.range(.rotation), step: 1,
                               unit: "°", decimals: 0, mixed: rotationMixed,
                               onChange: { edit(.rotation, to: $0) }, onEnd: { (drag, turned) = (nil, 0) })
                .suiteControl(id: "suite.transform.rotation", enabled: reason == nil, reason: reason)
                .help(reason ?? (rotationMixed ? Self.mixedHelp : ""))
            HStack(spacing: SuiteSpacing.xs) {
                Text(Self.flipLabel)
                    .font(SuiteFont.inspectorLabel)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .padding(.horizontal, SuiteSpacing.m)
                    .accessibilityHidden(true)
                ForEach(Self.flips(selection: selection, help: help, flipHelp: flipHelp, onIntent: onIntent), id: \.id) {
                    InspectorAction($0, iconOnly: true)
                }
            }
        }
        .disabled(reason != nil)
        .help(reason ?? "")
    }

    /// One row edit: the gesture's token (made on its first change), then the one intent it asks for.
    private func edit(_ row: TransformRow, to value: Double) {
        guard let selection else { return }
        let token = CoalesceKey.token(drag)
        drag = token
        guard let intent = Self.intent(row, to: value, from: selection, drag: token, mixed: rotationMixed, turned: turned)
        else { return }
        if row == .rotation, rotationMixed { turned = value }
        onIntent(intent)
    }

    /// Rotation's label: "Rotate By" while the items' turns differ, since a typed value then turns each by that much.
    nonisolated static func rotationLabel(mixed: Bool) -> String { mixed ? "Rotate By" : "Rotation" }

    nonisolated static let mixedHelp = "The items are turned differently: a value turns each one by that much more."

    /// The visible name in front of the icon-only flips; each button keeps its full name as help and label.
    nonisolated static let flipLabel = "Flip"

    /// Why nothing can transform: no selection, or the host's `help`; nil when the rows act.
    nonisolated static func reason(selection: TransformBox?, help: String?) -> String? {
        selection == nil ? noSelection : help
    }

    nonisolated static let noSelection = "Select something to transform."

    /// What each row may hold: X and Y anywhere on a large canvas, W and H at least 1, Rotation one turn.
    nonisolated static func range(_ row: TransformRow) -> ClosedRange<Double> {
        switch row {
        case .x, .y: -100_000...100_000
        case .w, .h: 1...100_000
        case .rotation: -180...180
        }
    }

    /// The help a row shows for a value outside its range.
    nonisolated static func rangeHelp(_ row: TransformRow) -> String {
        NumericInput.rangeHelp(range(row), decimals: 0, unit: row == .rotation ? "°" : "")
    }

    /// The row's value for `t`: the box's origin and size in document points, its turn in degrees.
    nonisolated static func value(_ row: TransformRow, of t: TransformBox) -> Double {
        switch row {
        case .x: t.box.minX
        case .y: t.box.minY
        case .w: t.box.width
        case .h: t.box.height
        case .rotation: t.degrees
        }
    }

    /// The one intent setting `row` to `value` asks for: `.rotate` by the difference, `.set` with the box
    /// moved, or scaled about its left (W) or top (H) side so that side stays on screen when turned. Nil when
    /// it changes nothing or the value can't be held. `mixed` (several turns): Rotation turns by `value` less
    /// what this gesture already `turned`, sent even when it equals the shown value.
    nonisolated static func intent(_ row: TransformRow, to value: Double, from t: TransformBox, drag: String?,
                                   mixed: Bool = false, turned: Double = 0) -> TransformIntent? {
        guard value.isFinite, range(row).contains(value) else { return nil }
        if row == .rotation, mixed { return .rotate(by: value - turned, drag: drag) }
        guard value != Self.value(row, of: t) else { return nil }
        let b = t.box
        var next = t
        switch row {
        case .rotation: return .rotate(by: value - t.degrees, drag: drag)
        case .x: next.box = Rect(minX: value, minY: b.minY, maxX: value + b.width, maxY: b.maxY)
        case .y: next.box = Rect(minX: b.minX, minY: value, maxX: b.maxX, maxY: value + b.height)
        case .w where b.width > 0: next = TransformRules.scaled(t, sx: value / b.width, sy: 1, about: .left)
        case .h where b.height > 0: next = TransformRules.scaled(t, sx: 1, sy: value / b.height, about: .top)
        case .w: next.box = Rect(minX: b.minX, minY: b.minY, maxX: b.minX + value, maxY: b.maxY)
        case .h: next.box = Rect(minX: b.minX, minY: b.minY, maxX: b.maxX, maxY: b.minY + value)
        }
        return .set(next, drag: drag)
    }

    /// Flip Horizontal and Flip Vertical, each asking for one `.flip`; disabled with the reason, or `flipHelp`.
    @MainActor static func flips(selection: TransformBox?, help: String?, flipHelp: String?,
                                 onIntent: @escaping @MainActor (TransformIntent) -> Void) -> [ToolbarAction] {
        let why = reason(selection: selection, help: help) ?? flipHelp
        return [
            ToolbarAction(FlipDirection.horizontal.title, systemImage: FlipDirection.horizontal.systemImage,
                          unavailableHelp: why, identifier: "suite.transform.flip-horizontal") { onIntent(.flip(.horizontal)) },
            ToolbarAction(FlipDirection.vertical.title, systemImage: FlipDirection.vertical.systemImage,
                          unavailableHelp: why, identifier: "suite.transform.flip-vertical") { onIntent(.flip(.vertical)) },
        ]
    }
}

extension FlipDirection {
    /// The flip's name in every inspector and Object or Image menu.
    public var title: String { self == .horizontal ? "Flip Horizontal" : "Flip Vertical" }

    /// The flip's SF Symbol in every inspector and menu: Apple's mirror symbol, two triangles facing over
    /// the axis, not the plain two-way arrows a move or resize draws.
    public var systemImage: String {
        self == .horizontal
            ? "arrow.left.and.right.righttriangle.left.righttriangle.right"
            : "arrow.up.and.down.righttriangle.up.righttriangle.down"
    }
}
