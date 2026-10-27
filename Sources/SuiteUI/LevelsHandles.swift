// LevelsHandles.swift: the suite's Levels control, drawn under a
// HistogramView: an input ramp with the black point, midtone and white point
// handles, and, when the host passes output points, an output ramp with the
// output black and white handles. Values are the engine's: points in 0...1
// (sRGB-encoded), gamma over 1 brightens; the midtone handle sits where the
// curve gives half output (SuiteModel's LevelsMidtone), so it follows the
// black and white points. Dragging a handle moves it from where it was by the
// drag's distance (a press that doesn't move changes nothing) and sends
// `onChange`, then one `onEnd` on release through the suite's EditRun, so a
// click ends nothing; the host clamps (a black point can't pass the white). Each handle is one adjustable accessibility element
// labelled with its field ("Black Point"), valued `reading` (points 0...255,
// gamma to two places, "Mixed" while `mixed`), identified `id(handle)` and
// listed in suite.controls; increment and decrement step one level (gamma
// 0.01) and end the edit. Hover and press fill the handle with the accent.
// Owns presentation state only.
import SuiteModel
import SwiftUI

/// One handle of a LevelsHandles; the raw value is its default label.
public enum LevelsHandle: String, CaseIterable, Sendable {
    case inBlack = "Black Point", gamma = "Midtones", inWhite = "White Point"
    case outBlack = "Output Black", outWhite = "Output White"
}

/// What a LevelsHandles shows: input points and gamma, and output points when the host has them.
public struct LevelsValues: Equatable, Sendable {
    public var inBlack: Double, gamma: Double, inWhite: Double
    public var outBlack: Double?, outWhite: Double?
    public init(inBlack: Double, gamma: Double, inWhite: Double, outBlack: Double? = nil, outWhite: Double? = nil) {
        self.inBlack = inBlack; self.gamma = gamma; self.inWhite = inWhite
        self.outBlack = outBlack; self.outWhite = outWhite
    }

    /// The handle's value: a point in 0...1, or gamma; nil for an output handle the host left out.
    public func value(_ handle: LevelsHandle) -> Double? {
        switch handle {
        case .inBlack: inBlack
        case .gamma: gamma
        case .inWhite: inWhite
        case .outBlack: outBlack
        case .outWhite: outWhite
        }
    }
}

public struct LevelsHandles: View {
    private let values: LevelsValues
    private let gammaRange: ClosedRange<Double>
    private let mixed: Bool
    private let enabled: Bool
    private let reason: String?
    private let id: (LevelsHandle) -> String?
    private let onChange: @MainActor (LevelsHandle, Double) -> Void
    private let onEnd: @MainActor () -> Void
    @State private var hovered: LevelsHandle?
    @State private var dragged: LevelsHandle?
    /// The dragged handle's position (0...1) at the press.
    @State private var dragStart: Double?
    @State private var run = EditRun()

    /// `reason` is the tooltip and suite.controls reason while not `enabled`.
    public init(
        _ values: LevelsValues, gammaRange: ClosedRange<Double>, mixed: Bool = false, enabled: Bool = true,
        reason: String? = nil, id: @escaping (LevelsHandle) -> String? = { _ in nil },
        onChange: @escaping @MainActor (LevelsHandle, Double) -> Void, onEnd: @escaping @MainActor () -> Void
    ) {
        self.values = values
        self.gammaRange = gammaRange
        self.mixed = mixed
        self.enabled = enabled
        self.reason = reason
        self.id = id
        self.onChange = onChange
        self.onEnd = onEnd
    }

    public var body: some View {
        VStack(spacing: SuiteSpacing.xs) {
            track([.inBlack, .gamma, .inWhite])
            if values.outBlack != nil, values.outWhite != nil { track([.outBlack, .outWhite]) }
        }
        .disabled(!enabled)
        .help(enabled ? "" : reason ?? "")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Levels")
    }

    /// A ramp with `handles` over it, each centred on its position.
    private func track(_ handles: [LevelsHandle]) -> some View {
        GeometryReader { box in
            ZStack(alignment: .leading) {
                LinearGradient(colors: [SuiteColor.overlayInk, SuiteColor.overlayPaper], startPoint: .leading, endPoint: .trailing)
                    .frame(height: SuiteSpacing.xs)
                    .clipShape(.capsule)
                    .overlay(Capsule().strokeBorder(SuiteColor.separator, lineWidth: 1))
                ForEach(handles, id: \.self) { handle in
                    knob(handle, width: box.size.width)
                        .offset(x: Self.position(handle, values) * box.size.width - SuiteSize.curveHandleHit / 2)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: SuiteSize.curveHandleHit)
    }

    private func knob(_ handle: LevelsHandle, width: CGFloat) -> some View {
        let active = hovered == handle || dragged == handle
        return Triangle()
            .fill(active ? SuiteColor.accent : Self.fill(handle))
            .stroke(active ? SuiteColor.accent : Color.primary, lineWidth: 1)
            .frame(width: SuiteSize.curveHandle, height: SuiteSize.curveHandle)
            .frame(width: SuiteSize.curveHandleHit, height: SuiteSize.curveHandleHit)
            .contentShape(.rect)
            .onHover { hovered = $0 ? handle : (hovered == handle ? nil : hovered) }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        dragged = handle
                        let start = dragStart ?? Self.position(handle, values)
                        dragStart = start
                        guard drag.translation.width != 0 else { return }
                        _ = run.change()
                        let fraction = start + drag.translation.width / max(width, 1)
                        onChange(handle, Self.value(handle, at: fraction, values, gammaRange: gammaRange))
                    }
                    .onEnded { _ in
                        dragged = nil
                        dragStart = nil
                        if run.end() { onEnd() }
                    })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(handle.rawValue)
            .accessibilityValue(Text(verbatim: mixed ? "Mixed" : Self.reading(handle, values)))
            .accessibilityAdjustableAction { direction in
                guard let value = values.value(handle) else { return }
                let step = (handle == .gamma ? 0.01 : 1.0 / 255) * (direction == .increment ? 1 : -1)
                onChange(handle, value + step)
                onEnd()
            }
            .suiteControl(id: id(handle), enabled: enabled, reason: enabled ? nil : reason)
    }

    /// Black and output black draw dark, white and output white light, midtones grey.
    nonisolated private static func fill(_ handle: LevelsHandle) -> Color {
        switch handle {
        case .inBlack, .outBlack: SuiteColor.overlayInk
        case .inWhite, .outWhite: SuiteColor.overlayPaper
        case .gamma: SuiteColor.valueFill
        }
    }

    /// Where `handle` sits on its ramp, 0...1: the point itself, or the midtone between the input points.
    nonisolated public static func position(_ handle: LevelsHandle, _ values: LevelsValues) -> Double {
        let raw = handle == .gamma
            ? LevelsMidtone.position(black: values.inBlack, white: values.inWhite, gamma: values.gamma)
            : values.value(handle) ?? 0
        return raw.isFinite ? min(max(raw, 0), 1) : 0
    }

    /// The value a drag to `fraction` (0...1 across the ramp) asks for: the fraction itself,
    /// or for the midtone the gamma that puts it there.
    nonisolated public static func value(
        _ handle: LevelsHandle, at fraction: Double, _ values: LevelsValues, gammaRange: ClosedRange<Double>
    ) -> Double {
        let x = fraction.isFinite ? min(max(fraction, 0), 1) : 0
        guard handle == .gamma else { return x }
        return LevelsMidtone.gamma(at: x, black: values.inBlack, white: values.inWhite, in: gammaRange)
    }

    /// A point as a whole level 0...255, gamma to two places ("1.00").
    nonisolated public static func reading(_ handle: LevelsHandle, _ values: LevelsValues) -> String {
        let value = values.value(handle) ?? 0
        guard handle == .gamma else { return String(Int((value * 255).rounded())) }
        let hundredths = Int((value * 100).rounded())
        let fraction = String(hundredths % 100)
        return "\(hundredths / 100)." + String(repeating: "0", count: 2 - fraction.count) + fraction
    }
}

/// A handle: a small triangle pointing up at the ramp.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
