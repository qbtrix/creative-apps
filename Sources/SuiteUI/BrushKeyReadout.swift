// BrushKeyReadout.swift (brush-keys BK-5): the capsule a canvas shows for `duration` seconds after a brush key, "Size
// 25 px" or "Opacity 45%". A new `serial` restarts it; under Reduce Motion it shows without the fade.
import SuiteKernel
import SwiftUI

public struct BrushKeyReadout: View {
    /// How long, in seconds, the readout stays after the last key.
    public nonisolated static let duration = 0.8
    private let action: BrushKeyAction?
    private let serial: Int
    @State private var shown: String?
    @Environment(\.suiteReduceMotion) private var reduceMotion

    /// The readout for `action`; a new `serial` shows it again for `duration`.
    public init(action: BrushKeyAction?, serial: Int) {
        self.action = action
        self.serial = serial
    }

    /// What the readout says for `action`.
    public nonisolated static func text(for action: BrushKeyAction) -> String {
        switch action {
        case .brush(.size(let px)): "Size \(NumericInput.text(px, decimals: 0, unit: "px"))"
        case .brush(.hardness(let p)): "Hardness \(NumericInput.text(p, decimals: 0, unit: "%"))"
        case .brush(.opacity(let p)): "Opacity \(NumericInput.text(p, decimals: 0, unit: "%"))"
        case .brush(.flow(let p)): "Flow \(NumericInput.text(p, decimals: 0, unit: "%"))"
        case .brush(.spacing(let p)): "Spacing \(NumericInput.text(p, decimals: 0, unit: "%"))"
        case .layerOpacity(let p): "Layer opacity \(NumericInput.text(p, decimals: 0, unit: "%"))"
        }
    }

    public var body: some View {
        ZStack {
            if let shown {
                Text(shown)
                    .font(SuiteFont.pill)
                    .foregroundStyle(SuiteColor.textPrimary)
                    .padding(SuiteInset.pill)
                    .background(SuiteColor.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(SuiteColor.outline, lineWidth: 1))
                    .fixedSize()
                    .transition(.opacity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(shown)
                    .accessibilityValue(shown)
                    .accessibilityIdentifier("suite.brush.readout")
            }
        }
        .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: shown)
        .allowsHitTesting(false)
        .task(id: serial) {
            guard let action else { return }
            shown = Self.text(for: action)
            try? await Task.sleep(for: .seconds(Self.duration))
            if !Task.isCancelled { shown = nil }
        }
    }
}
