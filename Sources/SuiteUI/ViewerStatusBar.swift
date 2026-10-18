// ViewerStatusBar.swift: the row under a canvas or viewer, its facts drawn as
// status pills, right-aligned and 4 pt apart: the zoom percent, the document
// size, then each view of the trailing slot (a tool name, a render time, a
// View menu) in its own pill. A pill is a 20 pt capsule on the row fill (24
// to hit) in the 10 pt pill type and secondary text. A trailing view marked
// `.statusPill(.toggle(isOn: true))` takes the selected tint and accent text,
// and one marked `.statusPill(.warning)` the warning tint and color with a
// triangle. Chrome, but flat: no glass and no band. The zoom text comes from
// ViewerZoom, so every app formats it the same way. `message` is a refusal
// sentence at the leading edge (caption text in the error color with the
// exclamation circle, not a pill: nothing changed), and `previewHelp` adds
// the last pill, a "Preview data" warning whose tooltip and accessibility hint
// say the window shows built-in sample data.
import SwiftUI

/// How a pill in a ViewerStatusBar draws.
public enum StatusPillStyle: Hashable, Sendable {
    case plain
    case toggle(isOn: Bool)
    case warning
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
    /// Marks a view in ViewerStatusBar's trailing slot as a toggle or warning pill.
    public func statusPill(_ style: StatusPillStyle) -> some View {
        containerValue(\.statusPillStyle, style)
    }
}

public struct ViewerStatusBar<Trailing: View>: View {
    private let zoom: Double
    private let size: String
    private let message: (text: String, identifier: String)?
    private let preview: (help: String, identifier: String)?
    private let trailing: Trailing

    /// `zoom` is the scale the viewer draws at (1 is 100%; ViewerZoom.fitScale
    /// gives CanvasSurface's), `size` the document size ("1920 × 1080 px").
    /// `message` is a leading refusal, `preview` the "Preview data" pill's help and identifier.
    public init(
        zoom: Double, size: String, message: (text: String, identifier: String)? = nil,
        preview: (help: String, identifier: String)? = nil, @ViewBuilder trailing: () -> Trailing
    ) {
        self.zoom = zoom
        self.size = size
        self.message = message
        self.preview = preview
        self.trailing = trailing()
    }

    /// The leading refusal's type: caption text, not the pill type.
    static var messageFont: Font { SuiteFont.caption }

    public var body: some View {
        HStack(spacing: SuiteSpacing.pillGap) {
            if let message {
                Label(message.text, systemImage: "exclamationmark.circle")
                    .font(Self.messageFont)
                    .foregroundStyle(SuiteColor.stateError)
                    .accessibilityIdentifier(message.identifier)
            }
            Spacer(minLength: SuiteSpacing.s)
            pill(.plain) {
                Text(ViewerZoom.percentText(zoom))
                    .foregroundStyle(SuiteColor.textPrimary)
                    .accessibilityLabel("Zoom \(ViewerZoom.percentText(zoom))")
            }
            pill(.plain) { Text(size) }
            ForEach(subviews: trailing) { view in
                pill(view.containerValues.statusPillStyle) { view }
            }
            if let preview {
                pill(.warning) {
                    Text("Preview data").accessibilityIdentifier(preview.identifier)
                        .help(preview.help)
                        .accessibilityHint(preview.help)
                }
            }
        }
        .lineLimit(1)
        .controlSize(SuiteSize.compactControl)
        .padding(.horizontal, SuiteSpacing.s)
        .padding(.vertical, SuiteSpacing.xxs)
        .background(SuiteColor.panel)
    }

    private func pill(_ style: StatusPillStyle, @ViewBuilder _ content: () -> some View) -> some View {
        let on = style == .toggle(isOn: true)
        return HStack(spacing: SuiteSpacing.xxs) {
            if style == .warning { Image(systemName: "exclamationmark.triangle.fill").imageScale(.small) }
            content()
        }
        .font(SuiteFont.pill)
        .foregroundStyle(style == .warning ? SuiteColor.stateWarning : on ? SuiteColor.accentText : SuiteColor.textSecondary)
        .padding(SuiteInset.pill)
        .frame(height: SuiteSize.pill)
        .background(
            style == .warning ? SuiteColor.warningTint : on ? SuiteColor.selectedTint : SuiteColor.row, in: Capsule())
        .frame(height: SuiteSize.pillHit)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

extension ViewerStatusBar where Trailing == EmptyView {
    public init(
        zoom: Double, size: String, message: (text: String, identifier: String)? = nil,
        preview: (help: String, identifier: String)? = nil
    ) {
        self.init(zoom: zoom, size: size, message: message, preview: preview) { EmptyView() }
    }
}
