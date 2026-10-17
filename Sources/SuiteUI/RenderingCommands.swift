// RenderingCommands.swift: the suite's View > Rendering submenu (canvas-host
// CH-4). `RenderingMenuModel` holds the menu's state over a preference (the
// fake until CH-9): its three items in order with their ids and the one
// checked, the status line under them, and `pick`, which writes the choice
// once. `RenderingMenu` draws it as an inline Picker, so the menu checks the
// current choice, with the status line as a disabled item under it;
// `RenderingPullDown` puts it behind a button, as the gallery page shows it;
// `RenderingCommands` adds it to the View menu after the toolbar group.
import Combine
import Observation
import SwiftUI

/// One choice in the Rendering menu.
public struct RenderingMenuItem: Identifiable, Equatable, Sendable {
    public let choice: RenderingChoice
    public let title: String
    /// The item's accessibility id, `RenderingControlID.item(choice)`.
    public let id: String
    public let isChecked: Bool

    /// The menu's title for a choice.
    public static func title(_ choice: RenderingChoice) -> String {
        switch choice {
        case .automatic: "Automatic"
        case .gpu: "GPU (Metal)"
        case .cpu: "CPU"
        }
    }

    /// The three items in menu order, the one for `checked` carrying the checkmark.
    public static func all(checked: RenderingChoice) -> [RenderingMenuItem] {
        RenderingChoice.allCases.map {
            RenderingMenuItem(choice: $0, title: title($0), id: RenderingControlID.item($0), isChecked: $0 == checked)
        }
    }
}

/// The Rendering menu's state over one preference. It follows the preference
/// through `observe`, so a write from anywhere moves the checkmark.
@MainActor @Observable
public final class RenderingMenuModel {
    public private(set) var choice: RenderingChoice
    @ObservationIgnored private let preference: any RenderingPreferenceReading
    @ObservationIgnored private var token: AnyCancellable?

    public init(preference: any RenderingPreferenceReading) {
        self.preference = preference
        choice = preference.choice
        token = preference.observe { [weak self] in self?.follow($0) }
    }

    /// On the fake preference, as the gallery and the beta's commands run until CH-9.
    public convenience init() {
        self.init(preference: FakeRenderingPreference())
    }

    public var items: [RenderingMenuItem] { RenderingMenuItem.all(checked: choice) }

    /// The backend in use, read when the menu draws.
    public var status: RenderingStatus { preference.status }

    /// The disabled line under the choices.
    public var statusLine: String { Self.statusLine(status) }

    /// "Drawing on <active>", or the note alone when there is one.
    public static func statusLine(_ status: RenderingStatus) -> String {
        guard let note = status.note else { return "Drawing on \(status.active)" }
        return note
    }

    /// Writes the picked choice to the preference once.
    public func pick(_ picked: RenderingChoice) {
        preference.set(picked)
        follow(preference.choice)
    }

    private func follow(_ next: RenderingChoice) {
        if choice != next { choice = next }
    }
}

/// The three choices as an inline Picker, so the menu checks the current one,
/// then the status line as a disabled item. Put it inside a `Menu`.
public struct RenderingMenu: View {
    private let model: RenderingMenuModel

    public init(model: RenderingMenuModel) {
        self.model = model
    }

    public var body: some View {
        Picker("Rendering", selection: Binding(get: { model.choice }, set: { model.pick($0) })) {
            ForEach(model.items) { item in
                Text(item.title).tag(item.choice).accessibilityIdentifier(item.id)
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
        Divider()
        // A menu draws a Text as a disabled item: the status line reads, never acts.
        Text(model.statusLine)
            .accessibilityIdentifier(RenderingControlID.status)
    }
}

/// The Rendering menu behind a pull-down button, as a settings page shows it.
public struct RenderingPullDown: View {
    private let model: RenderingMenuModel

    public init(model: RenderingMenuModel) {
        self.model = model
    }

    public var body: some View {
        Menu("Rendering") { RenderingMenu(model: model) }
            .menuStyle(.button)
            .fixedSize()
            .accessibilityIdentifier(RenderingControlID.menu)
    }
}

/// View > Rendering: the submenu after the toolbar group of the View menu.
public struct RenderingCommands: Commands {
    private let model: RenderingMenuModel

    public init(model: RenderingMenuModel) {
        self.model = model
    }

    public var body: some Commands {
        CommandGroup(after: .toolbar) {
            Menu("Rendering") { RenderingMenu(model: model) }
                .accessibilityIdentifier(RenderingControlID.menu)
        }
    }
}
