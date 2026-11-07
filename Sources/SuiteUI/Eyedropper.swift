// Eyedropper.swift (eyedropper EY-2 placeholders, EY-3 views): the eyedropper's three views. EyedropperButton is a
// colour row's button for the system screen sampler (NSColorSampler): a click opens it, a click on the screen picks
// that colour as the nearest 8-bit sRGB one, Escape picks nothing. SampleLoupe is an eyedropper tool's ring at the
// pointer: a band of the colour under it around a hollow centre, so the pixel it reads stays in view, with the hex
// in a pill below; hollow and "No colour here" when there is none. SampleSizeChips picks the square a tool reads,
// as ChoiceChips with the ids `suite.sample.size.<n>`. The views hold no state.
import AppKit
import SuiteKernel
import SwiftUI

/// The eyedropper button of a colour row: the system screen sampler; Escape picks nothing. It lights on hover and
/// press (HoverButtonStyle). Listed in
/// `suite.controls` as `suite.color.eyedropper`; with `help` it is disabled and that is its tooltip.
public struct EyedropperButton: View {
    /// The button's VoiceOver label and title.
    public static let title = "Pick a colour from the screen"
    private let help: String?
    private let onPick: @MainActor (HexColor) -> Void

    public init(help: String? = nil, onPick: @escaping @MainActor (HexColor) -> Void) {
        self.help = help
        self.onPick = onPick
    }

    public var body: some View {
        Button(action: sample) {
            Image(systemName: "eyedropper")
                .imageScale(.small)
                .frame(minWidth: SuiteSize.iconButtonHit, minHeight: SuiteSize.iconButtonHit)
                .contentShape(.rect)
        }
        .buttonStyle(HoverButtonStyle())
        .foregroundStyle(SuiteColor.textSecondary)
        .help(help ?? Self.title)
        .accessibilityLabel(Self.title)
        .disabled(help != nil)
        .suiteControl(id: "suite.color.eyedropper", enabled: help == nil, reason: help)
    }

    /// Opens the sampler. While it shows, clicks pick a colour, so the button can't be clicked twice.
    private func sample() {
        let onPick = onPick
        // AppKit calls the handler once, on the main thread: the colour clicked, or nil for Escape.
        NSColorSampler().show { picked in
            Task { @MainActor in
                if let hex = EyedropperButton.hex(picked) { onPick(hex) }
            }
        }
    }

    /// The sampler's colour, converted to sRGB, as the nearest 8-bit colour; nil when it picked nothing.
    nonisolated static func hex(_ color: NSColor?) -> HexColor? {
        guard let rgb = color?.usingColorSpace(.sRGB) else { return nil }
        return HexColor(FillColor(r: rgb.redComponent, g: rgb.greenComponent, b: rgb.blueComponent))
    }
}

/// An eyedropper tool's ring at the pointer: the colour under it and its hex, hollow when there is none.
public struct SampleLoupe: View {
    /// What the loupe reads when there is no colour under the pointer.
    public nonisolated static let empty = "No colour here"
    /// The ring's outer diameter: wider than a tool button, so the band reads at a glance.
    static let diameter = SuiteSize.toolButton + SuiteSpacing.m
    private let color: HexColor?
    private let point: CGPoint

    public init(color: HexColor?, at point: CGPoint) {
        self.color = color
        self.point = point
    }

    /// The hex the loupe shows and says, or `empty`.
    nonisolated static func text(for color: HexColor?) -> String { color?.text ?? empty }

    public var body: some View {
        ZStack {
            Circle().strokeBorder(color?.color ?? .clear, lineWidth: SuiteSpacing.s)
            Circle().strokeBorder(SuiteColor.overlayPaper, lineWidth: SuiteSize.pointMarkPaper)
            Circle().strokeBorder(SuiteColor.overlayInk, lineWidth: SuiteSize.pointMarkInk)
            Circle().strokeBorder(SuiteColor.overlayInk, lineWidth: SuiteSize.pointMarkInk).padding(SuiteSpacing.s)
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .overlay(alignment: .top) {
            Text(Self.text(for: color))
                .font(SuiteFont.pill)
                .foregroundStyle(SuiteColor.textPrimary)
                .padding(SuiteInset.pill)
                .background(SuiteColor.card, in: Capsule())
                .overlay(Capsule().strokeBorder(SuiteColor.outline, lineWidth: 1))
                .fixedSize()
                .offset(y: Self.diameter + SuiteSpacing.xs)
        }
        .position(point)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.text(for: color))
        .accessibilityIdentifier("suite.sample.loupe")
    }
}

/// The sample-size chips an eyedropper tool's options show: Point, 3 × 3 and 5 × 5.
public struct SampleSizeChips: View {
    /// One chip per size, each with its `suite.sample.size.<n>` identifier.
    static let options = SampleSize.allCases.map {
        InspectorOption(id: $0, title: $0.title, identifier: "suite.sample.size.\($0.rawValue)")
    }
    private let size: SampleSize
    private let onChange: @MainActor (SampleSize) -> Void

    public init(size: SampleSize, onChange: @escaping @MainActor (SampleSize) -> Void) {
        self.size = size
        self.onChange = onChange
    }

    public var body: some View {
        ChoiceChips(options: Self.options, selected: size, onSelect: onChange)
            .help("The square the eyedropper reads")
    }
}
