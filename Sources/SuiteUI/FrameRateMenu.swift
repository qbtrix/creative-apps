// FrameRateMenu.swift: the one frame rate menu (frame-rates packet, FR-5),
// shared by the gallery's timeline page, and the composition and scene
// settings that adopt it later (FR-8, FR-10). One SwiftUI Menu over
// SuiteKernel's FrameRate.common, slowest first; each item is titled as the
// time.rates commands title the rate ("29.97 fps", FrameRate.description),
// and an inline Picker checks the bound rate. It takes the rate and an
// `onSelect` closure, never a binding: apps can't bind to their Model. What
// the menu lists is plain Swift, `items(checked:)` (FrameRateMenuTests).
import SuiteKernel
import SwiftUI

/// One item of the rate menu: the rate, its title and whether it is the bound one.
public struct FrameRateMenuItem: Identifiable, Hashable, Sendable {
    public let rate: FrameRate
    public let title: String
    public let isChecked: Bool
    public var id: FrameRate { rate }
}

/// A Menu of the common frame rates, its title the bound rate's, the bound rate checked.
public struct FrameRateMenu: View {
    private let rate: FrameRate
    private let onSelect: @MainActor (FrameRate) -> Void

    public init(rate: FrameRate, onSelect: @escaping @MainActor (FrameRate) -> Void) {
        self.rate = rate
        self.onSelect = onSelect
    }

    /// The menu's items in order, `rate`'s checked; a rate off the list checks none.
    nonisolated public static func items(checked rate: FrameRate) -> [FrameRateMenuItem] {
        FrameRate.common.map { FrameRateMenuItem(rate: $0, title: $0.description, isChecked: $0 == rate) }
    }

    public var body: some View {
        Menu {
            Picker("Frame Rate", selection: Binding(get: { rate }, set: { onSelect($0) })) {
                ForEach(Self.items(checked: rate)) { Text($0.title).tag($0.rate) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Text(rate.description)
        }
        .menuStyle(.button)
        .fixedSize()
        .help("Frame Rate")
        .accessibilityLabel("Frame Rate")
    }
}
