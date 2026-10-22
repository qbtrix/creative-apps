// FrameRateMenu.swift: the one frame rate menu (frame-rates packet, FR-5),
// shared by the gallery's timeline page, and the composition and scene
// settings that adopt it later (FR-8, FR-10). One SwiftUI Menu over
// SuiteKernel's FrameRate.common, slowest first; each item is titled as the
// time.rates commands title the rate ("29.97 fps", FrameRate.description),
// and an inline Picker checks the bound rate. It draws InspectorPickerRow's
// value menu (InspectorValueMenu, #4362): the rate and a chevron, plain. It takes the rate and an
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

    /// The value menu it draws, InspectorPickerRow's (#4362): the items as its
    /// options, titled with the bound rate even when that is off the list.
    var menu: InspectorValueMenu<FrameRate> {
        let options = Self.items(checked: rate).map { InspectorOption(id: $0.rate, title: $0.title) }
        return InspectorValueMenu(
            "Frame Rate", options: options, selection: rate, title: rate.description, onChange: { onSelect($0) })
    }

    public var body: some View {
        menu
            .controlSize(SuiteSize.compactControl)
            .help("Frame Rate")
    }
}
