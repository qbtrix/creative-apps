// Eyedropper.swift (eyedropper EY-2 placeholders, EY-3 views): the eyedropper's three views. EyedropperButton is a
// colour row's button for the system screen sampler; SampleLoupe is an eyedropper tool's ring at the pointer with
// the colour under it; SampleSizeChips picks the square a tool reads. Until EY-3 the button is disabled and says
// why, the loupe is a plain ring and the chips a plain segmented Picker; no colour row shows the button yet.
import SuiteKernel
import SwiftUI

/// The eyedropper button of a colour row: the system screen sampler; Escape picks nothing.
/// EY-2 placeholder: disabled, its tooltip saying why, listed in `suite.controls` as `suite.color.eyedropper`.
public struct EyedropperButton: View {
    /// The button's VoiceOver label and title.
    public static let title = "Pick a colour from the screen"
    /// Why the placeholder can't pick yet.
    static let notBuilt = "Picking a colour from the screen isn't built yet."
    private let help: String?
    private let onPick: @MainActor (HexColor) -> Void

    public init(help: String? = nil, onPick: @escaping @MainActor (HexColor) -> Void) {
        self.help = help
        self.onPick = onPick
    }

    public var body: some View {
        Button {} label: { Label(Self.title, systemImage: "eyedropper") }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(help ?? Self.notBuilt)
            .disabled(true)
            .suiteControl(id: "suite.color.eyedropper", enabled: false, reason: help ?? Self.notBuilt)
    }
}

/// An eyedropper tool's ring at the pointer: the colour under it and its hex, hollow when there is none.
/// EY-2 placeholder: the ring and the hex under it, centred on `point`; EY-3 sizes and draws it.
public struct SampleLoupe: View {
    /// What the loupe reads when there is no colour under the pointer.
    public static let empty = "No colour here"
    private let color: HexColor?
    private let point: CGPoint

    public init(color: HexColor?, at point: CGPoint) {
        self.color = color
        self.point = point
    }

    public var body: some View {
        VStack(spacing: SuiteSpacing.xs) {
            Circle()
                .fill(color?.color ?? .clear)
                .overlay(Circle().strokeBorder(SuiteColor.overlayPaper, lineWidth: SuiteSize.pointMarkPaper))
                .overlay(Circle().strokeBorder(SuiteColor.overlayInk, lineWidth: SuiteSize.pointMarkInk))
                .frame(width: SuiteSize.toolButton, height: SuiteSize.toolButton)
            Text(color?.text ?? Self.empty)
                .font(SuiteFont.caption)
        }
        .position(point)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(color?.text ?? Self.empty)
        .accessibilityIdentifier("suite.sample.loupe")
    }
}

/// The sample-size chips an eyedropper tool's options show.
/// EY-2 placeholder: a system segmented Picker over the three sizes; EY-3 gives it the chip look.
public struct SampleSizeChips: View {
    private let size: SampleSize
    private let onChange: @MainActor (SampleSize) -> Void

    public init(size: SampleSize, onChange: @escaping @MainActor (SampleSize) -> Void) {
        self.size = size
        self.onChange = onChange
    }

    public var body: some View {
        Picker("Sample Size", selection: Binding(get: { size }, set: { onChange($0) })) {
            ForEach(SampleSize.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(SuiteSize.compactControl)
        .fixedSize()
        .help("The square the eyedropper reads")
    }
}
