// RenderingPreference.swift: the suite's live View > Rendering preference
// (canvas-host CH-2). Every app process reads one key, `suite.rendering`, in
// the suite's shared defaults. Until CH-7 fills the store, this type answers
// with its fake's values and a write just records itself and reaches the fake;
// CH-7 keeps these signatures. The control ids of the host and the Rendering
// menu live here too, so the host, the menu and the journeys share them.
import Combine
import Foundation

/// The accessibility ids the canvas host and the Rendering menu use.
public enum RenderingControlID {
    /// The canvas host, as `CanvasViewport` names it today.
    public static let canvas = "suite.canvas"
    /// The host's live overlay layer.
    public static let overlay = "suite.canvas.overlay"
    /// The View > Rendering submenu.
    public static let menu = "suite.menu.rendering"
    /// The disabled status line under the three choices.
    public static let status = "suite.settings.rendering.status"

    /// A choice's menu item: `suite.settings.rendering.automatic|gpu|cpu`, the ids kept from the pane design.
    public static func item(_ choice: RenderingChoice) -> String {
        "suite.settings.rendering.\(choice.rawValue)"
    }
}

/// The live preference. Stubbed: it reads and writes its `store`, a fake, until CH-7.
@MainActor
public final class RenderingPreference: RenderingPreferenceReading {
    /// The one key in the suite's shared defaults.
    public nonisolated static let key = "suite.rendering"

    /// The choice a stored raw value names; nil when it is missing or names no choice, so the caller keeps its default.
    public nonisolated static func decode(_ raw: String?) -> RenderingChoice? {
        guard let raw else { return nil }
        return RenderingChoice(rawValue: raw)
    }

    private let store: FakeRenderingPreference

    /// Every choice `set` was given, in order, a repeat included: the stub's record of what CH-7 will write.
    public private(set) var writes: [RenderingChoice] = []

    public init(store: FakeRenderingPreference = FakeRenderingPreference()) {
        self.store = store
    }

    public var choice: RenderingChoice { store.choice }

    public var status: RenderingStatus { store.status }

    public func set(_ choice: RenderingChoice) {
        writes.append(choice); store.set(choice)
    }

    public func observe(_ onChange: @escaping @Sendable @MainActor (RenderingChoice) -> Void) -> AnyCancellable {
        store.observe(onChange)
    }
}
