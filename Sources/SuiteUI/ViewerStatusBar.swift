// ViewerStatusBar.swift: the row under a canvas or viewer, its facts drawn as
// status pills, right-aligned and 4 pt apart: the zoom percent (none when
// `zoom` is nil, as in a photo grid), the document size, then each view of the trailing slot (a tool name, a render time, a
// View menu) in its own pill. A pill is a 20 pt capsule on the row fill (24
// to hit) in the 10 pt pill type and secondary text. A trailing view marked
// `.statusPill(.toggle(isOn: true))` takes the selected tint and accent text,
// one marked `.statusPill(.warning)` the warning tint and color with a
// triangle, and one marked `.statusPill(.error)` (a failed save or render)
// the error tint and color with an exclamation circle. Chrome, but flat: no glass and no band. The zoom text comes from
// ViewerZoom, so every app formats it the same way. StatusPillFace is one pill on its own, for
// a hint over a canvas; its tint sits on the opaque panel color, so it reads off the bar too.
import SwiftUI

/// How a pill in a ViewerStatusBar draws.
public enum StatusPillStyle: Hashable, Sendable {
    case plain
    case toggle(isOn: Bool)
    case warning
    case error

    /// The symbol before the pill's text: a triangle for a warning, an
    /// exclamation circle for an error (design.md State colors).
    var symbol: String? {
        switch self {
        case .warning: "exclamationmark.triangle.fill"
        case .error: "exclamationmark.circle.fill"
        case .plain, .toggle: nil
        }
    }

    /// The pill's text and symbol color.
    var foreground: Color {
        switch self {
        case .warning: SuiteColor.stateWarning
        case .error: SuiteColor.stateError
        case .toggle(isOn: true): SuiteColor.accentText
        case .plain, .toggle: SuiteColor.textSecondary
        }
    }

    /// The capsule's fill.
    var fill: Color {
        switch self {
        case .warning: SuiteColor.warningTint
        case .error: SuiteColor.errorTint
        case .toggle(isOn: true): SuiteColor.selectedTint
        case .plain, .toggle: SuiteColor.row
        }
    }
}

private struct StatusPillStyleKey: ContainerValueKey {
    static let defaultValue = StatusPillStyle.plain
}

extension ContainerValues {
    var statusPillStyle: StatusPillStyle {
        get { self[StatusPillStyleKey.self] }
        set { self[StatusPillStyleKey.self] = newValue }
    }
}

extension View {
    /// Marks a view in ViewerStatusBar's trailing slot as a toggle, warning or error pill.
    public func statusPill(_ style: StatusPillStyle) -> some View {
        containerValue(\.statusPillStyle, style)
    }
}

public struct ViewerStatusBar<Trailing: View>: View {
    private let zoom: Double?
    private let size: String
    private let trailing: Trailing
    private var composing: any StatusPillComposing = SuiteStatusPills()
    private var documentSize: PlaneExtent?
    @Environment(\.chipProbe) private var probe

    /// `zoom` is the scale the viewer draws at (1 is 100%; ViewerZoom.fitScale
    /// gives CanvasSurface's; nil hides the zoom pill), `size` the document
    /// size ("1920 × 1080 px").
    public init(zoom: Double?, size: String, @ViewBuilder trailing: () -> Trailing) {
        self.zoom = zoom
        self.size = size
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.pillGap) {
            Spacer(minLength: SuiteSpacing.s)
            if let zoomText {
                pill(.plain) {
                    Text(zoomText)
                        .foregroundStyle(SuiteColor.textPrimary)
                        .accessibilityLabel("Zoom \(zoomText)")
                }
                .help("Zoom")
            }
            pill(.plain) { Text(sizeText) }
            ForEach(subviews: trailing) { view in
                trailingPill(view)
            }
        }
        .lineLimit(1)
        .controlSize(SuiteSize.compactControl)
        .padding(.horizontal, SuiteSpacing.s)
        .padding(.vertical, SuiteSpacing.xxs)
        .background(SuiteColor.panel)
    }

    private func pill(_ style: StatusPillStyle, @ViewBuilder _ content: () -> some View) -> some View {
        StatusPillFace(style, content: content)
            .frame(height: SuiteSize.pillHit)
            .accessibilityAddTraits(style == .toggle(isOn: true) ? .isSelected : [])
    }
}

/// One status pill as ViewerStatusBar draws it, for a pill shown on its own (a canvas hint):
/// the style's symbol and colors, 20 pt tall. Its tint sits on the opaque panel color, so it
/// reads the same over a canvas as on the bar's row.
public struct StatusPillFace<Content: View>: View {
    private let style: StatusPillStyle
    private let content: Content

    public init(_ style: StatusPillStyle, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.xxs) {
            if let symbol = style.symbol { Image(systemName: symbol).imageScale(.small) }
            content
        }
        .font(SuiteFont.pill)
        .foregroundStyle(style.foreground)
        .padding(SuiteInset.pill)
        .frame(height: SuiteSize.pill)
        .background(style.fill, in: Capsule())
        .background(SuiteColor.panel, in: Capsule())
    }
}

extension ViewerStatusBar where Trailing == EmptyView {
    public init(zoom: Double?, size: String) {
        self.init(zoom: zoom, size: size) { EmptyView() }
    }
}

/// A trailing pill that acts: `.statusPill(_:id:help:reason:action:)` makes
/// the pill a button that registers `id` with `.suiteControl` (disabled with
/// `reason`, which is then its tooltip) and emits the `press` series.
struct StatusPillControl {
    let id: String
    let help: String
    let reason: String?
    let action: @MainActor () -> Void

    /// What the pill's tooltip shows: the reason it can't act, else its help.
    var tooltip: String { reason ?? help }
}

private struct StatusPillControlKey: ContainerValueKey {
    static var defaultValue: StatusPillControl? { nil }
}

extension ContainerValues {
    var statusPillControl: StatusPillControl? {
        get { self[StatusPillControlKey.self] }
        set { self[StatusPillControlKey.self] = newValue }
    }
}

extension View {
    /// Marks a view in ViewerStatusBar's trailing slot as a pill that acts on
    /// a click (a toggle such as Onion): registered as `id`, disabled while
    /// `reason` is set.
    public func statusPill(
        _ style: StatusPillStyle, id: String, help: String, reason: String? = nil,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        statusPill(style)
            .containerValue(\.statusPillControl, StatusPillControl(id: id, help: help, reason: reason, action: action))
    }
}

extension StatusPillStyle {
    /// The view style for a StatusPillComposing pill's style.
    public init(_ style: PillStyle) {
        switch style {
        case .plain: self = .plain
        case .toggle(let isOn): self = .toggle(isOn: isOn)
        case .warning: self = .warning
        }
    }
}

extension ViewerStatusBar {
    /// The bar over a document size: the zoom and size text come from
    /// `composing` (SuiteStatusPills formats every app's the same way).
    public init(
        zoom: Double, documentSize: PlaneExtent, composing: some StatusPillComposing = SuiteStatusPills(),
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(zoom: zoom, size: "", trailing: trailing)
        self.documentSize = documentSize
        self.composing = composing
    }

    /// The zoom pill's text: the composer's first pill; nil without a zoom.
    var zoomText: String? {
        guard let zoom else { return nil }
        return faces.first?.text ?? ViewerZoom.percentText(zoom)
    }

    /// The size pill's text: the composer's second pill for a document size,
    /// else the `size` string the bar was built with ("No file open").
    var sizeText: String {
        documentSize == nil ? size : faces.dropFirst().first?.text ?? size
    }

    private var faces: [StatusPill] {
        composing.pills(zoom: zoom ?? 1, documentSize: documentSize ?? PlaneExtent(width: 0, height: 0), trailing: [])
    }

    @ViewBuilder fileprivate func trailingPill(_ view: Subview) -> some View {
        let style = view.containerValues.statusPillStyle
        if let control = view.containerValues.statusPillControl {
            Button { ChipProbe.press(probe, control.action) } label: { pill(style) { view } }
                .buttonStyle(.plain)
                .disabled(control.reason != nil)
                .help(control.tooltip)
                .suiteControl(id: control.id, enabled: control.reason == nil, reason: control.reason)
        } else {
            pill(style) { view }
        }
    }
}

extension ViewerStatusBar where Trailing == EmptyView {
    public init(zoom: Double, documentSize: PlaneExtent, composing: some StatusPillComposing = SuiteStatusPills()) {
        self.init(zoom: zoom, documentSize: documentSize, composing: composing) { EmptyView() }
    }
}
