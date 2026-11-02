// GalleryBrushKeys.swift (brush-keys BK-5): the gallery's `brush-keys` page, a fake brush that `[`, `]`, Shift and
// digits edit through ToolKeys.brushAction. The digit buffer is a box the body never reads: one body per press.
import AppKit
import SuiteKernel
import SwiftUI

enum GalleryBrushKeys {
    static let name = "brush-keys"
    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryBrushKeysPage()) }]

    /// The status line for `settings`: "Size 20 px, opacity 100%".
    static func status(_ settings: BrushSettings) -> String {
        "Size \(NumericInput.text(settings.size, decimals: 0, unit: "px")), "
            + "opacity \(NumericInput.text(settings.opacity, decimals: 0, unit: "%"))"
    }

    /// SwiftUI's modifiers as the contracts' KeyModifiers.
    static func modifiers(_ held: EventModifiers) -> KeyModifiers {
        let pairs: [(EventModifiers, KeyModifiers)] = [(.shift, .shift), (.option, .option), (.command, .command)]
        return pairs.reduce(into: KeyModifiers()) { mods, pair in if held.contains(pair.0) { mods.insert(pair.1) } }
    }
}

/// The opacity digits typed so far; a box, so typing one changes no state the body reads.
@MainActor final class GalleryBrushKeyBuffer { var digits = OpacityDigits() }

struct GalleryBrushKeysPage: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif
    @State private var settings = BrushSettings()
    @State private var last: BrushKeyAction?
    @State private var serial = 0
    @State private var buffer = GalleryBrushKeyBuffer()
    @FocusState private var focused: Bool

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Brush keys").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText).accessibilityAddTraits(.isHeader)
            InspectorSliderRow(
                "Size", value: settings.size, in: BrushSettings.ranges.size, step: 1, unit: "px", decimals: 0,
                onChange: { edit(.size($0)) })
                .suiteControl(id: "suite.gallery.brush-size", enabled: true, reason: nil)
            InspectorSliderRow(
                "Opacity", value: settings.opacity, in: BrushSettings.ranges.percent, step: 1, unit: "%", decimals: 0,
                onChange: { edit(.opacity($0)) })
                .suiteControl(id: "suite.gallery.brush-opacity", enabled: true, reason: nil)
            canvas
            let status = GalleryBrushKeys.status(settings)
            Text(status).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
                .accessibilityValue(status).accessibilityIdentifier("suite.gallery.brush-status")
        }
        .padding(SuiteSpacing.m)
    }

    private var canvas: some View {
        ZStack(alignment: .top) {
            BrushCursorMark(point: CGPoint(x: SuiteSize.contentMinimum.width / 2, y: SuiteSize.contentMinimum.height / 2),
                            diameter: settings.size, zoom: 1)
            BrushKeyReadout(action: last, serial: serial).padding(SuiteSpacing.s)
        }
        .frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
        .background(SuiteColor.artboard)
        .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        .contentShape(.rect)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in route(press) }
        .onTapGesture { focused = true }
        .onAppear { focused = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Brush canvas")
        .accessibilityValue(last.map(BrushKeyReadout.text(for:)) ?? "No brush key yet")
        .accessibilityIdentifier("suite.gallery.brush-canvas")
    }

    /// A brush key edits the fake brush and shows the readout; any other key goes on.
    private func route(_ press: KeyPress) -> KeyPress.Result {
        let action = ToolKeys.brushAction(
            forKey: press.characters, modifiers: GalleryBrushKeys.modifiers(press.modifiers),
            at: ProcessInfo.processInfo.systemUptime, firstResponder: NSApplication.shared.keyWindow?.firstResponder,
            settings: settings, digits: &buffer.digits)
        guard let action else { return .ignored }
        if case .brush(let change) = action { edit(change) }
        last = action
        serial += 1
        return .handled
    }

    private func edit(_ change: BrushEdit) {
        var next = settings
        if next.apply(change) { settings = next }
    }
}
