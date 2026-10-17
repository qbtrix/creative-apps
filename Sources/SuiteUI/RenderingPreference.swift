// RenderingPreference.swift: the suite's live View > Rendering preference
// (canvas-host CH-2, filled by CH-7). Every app process reads one key,
// `suite.rendering`, in the suite's shared defaults domain. A write reaches the
// other instances in this process at once and posts a distributed notification
// so the other suite processes reread the key; each instance tells its
// observers once per change, never on a repeat. Device loss is per process:
// under Automatic it falls back to CPU with a note, under GPU it keeps GPU and
// says Metal stopped. `init(store:)` keeps CH-2's fake-backed form until CH-9
// moves the pages to the live store. The control ids of the host and the
// Rendering menu live here too, so the host, the menu and the journeys share them.
import Combine
import Foundation
import SuiteModel

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

/// The live preference: the suite's shared defaults, or (through `init(store:)`) a fake.
@MainActor
public final class RenderingPreference: RenderingPreferenceReading {
    /// The one key in the suite's shared defaults.
    public nonisolated static let key = "suite.rendering"

    /// The suite's shared defaults domain, which every app process opens.
    public nonisolated static let suiteName = SuiteIdentity.prefix + ".shared"

    /// The distributed notification a write posts; its object is the domain written.
    nonisolated static let changed = Notification.Name(SuiteIdentity.prefix + ".rendering-changed")

    /// The status note under Automatic once Metal stops.
    public nonisolated static let fallbackNote = "Drawing on CPU: Metal stopped"
    /// The status note under GPU once Metal stops: the choice is kept.
    public nonisolated static let gpuLostNote = "Metal stopped"

    /// The choice a stored raw value names; nil when it is missing or names no choice, so the caller keeps its default.
    public nonisolated static func decode(_ raw: String?) -> RenderingChoice? {
        guard let raw else { return nil }
        return RenderingChoice(rawValue: raw)
    }

    /// The live instances in this process, so a write reaches them at once.
    private static var live: [WeakPreference] = []

    private let store: FakeRenderingPreference?
    private let defaults: UserDefaults
    private let domain: String
    private var heard: RenderingChoice
    private var deviceLost = false
    private var observers: [UUID: @Sendable @MainActor (RenderingChoice) -> Void] = [:]
    private var watch: DistributedWatch?

    /// Every choice `set` was given, in order, a repeat included.
    public private(set) var writes: [RenderingChoice] = []

    /// Backed by a fake, as CH-2 built it: reads, writes and observers are the fake's.
    public init(store: FakeRenderingPreference = FakeRenderingPreference()) {
        self.store = store
        defaults = .standard
        domain = ""
        heard = store.choice
    }

    /// Live on `suiteName`'s defaults domain: `RenderingPreference.suiteName` in the apps, a scratch domain in tests.
    public init(suiteName: String) {
        let shared = UserDefaults(suiteName: suiteName) ?? .standard
        store = nil
        defaults = shared
        domain = suiteName
        heard = Self.decode(shared.string(forKey: Self.key)) ?? .automatic
        Self.live.removeAll { $0.preference == nil }
        Self.live.append(WeakPreference(self))
        watch = DistributedWatch(domain: suiteName) { [weak self] in
            let owner = self
            Task { @MainActor in owner?.refresh() }
        }
    }

    public var choice: RenderingChoice {
        if let store { return store.choice }
        return Self.decode(defaults.string(forKey: Self.key)) ?? .automatic
    }

    public var status: RenderingStatus {
        if let store { return store.status }
        switch choice {
        case .cpu:
            return RenderingStatus(active: "CPU", note: nil)
        case .gpu:
            return RenderingStatus(active: "GPU", note: deviceLost ? Self.gpuLostNote : nil)
        case .automatic:
            return deviceLost
                ? RenderingStatus(active: "CPU", note: Self.fallbackNote) : RenderingStatus(active: "GPU", note: nil)
        }
    }

    public func set(_ choice: RenderingChoice) {
        writes.append(choice)
        if let store {
            store.set(choice)
            return
        }
        defaults.set(choice.rawValue, forKey: Self.key)
        for instance in Self.live.compactMap({ $0.preference }) where instance.domain == domain {
            instance.refresh()
        }
        DistributedNotificationCenter.default().postNotificationName(
            Self.changed, object: domain, userInfo: nil, deliverImmediately: true)
    }

    public func observe(_ onChange: @escaping @Sendable @MainActor (RenderingChoice) -> Void) -> AnyCancellable {
        if let store { return store.observe(onChange) }
        let id = UUID()
        observers[id] = onChange
        // AnyCancellable may run this off the main actor (on deinit), so it hops back rather than assume isolation.
        return AnyCancellable { @Sendable [weak self] in
            let owner = self
            Task { @MainActor in owner?.removeObserver(id) }
        }
    }

    /// Metal stopped in this process. Under Automatic the status falls back to CPU with a note.
    public func loseDevice() {
        if let store {
            store.loseDevice()
            return
        }
        deviceLost = true
    }

    /// Rereads the key and tells the observers when it names a choice they have not heard yet.
    func refresh() {
        let now = choice
        guard now != heard else { return }
        heard = now
        for observer in observers.values { observer(now) }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}

@MainActor private struct WeakPreference {
    weak var preference: RenderingPreference?
    init(_ preference: RenderingPreference) { self.preference = preference }
}

/// Hears other processes' writes to one domain; stops hearing when released.
private final class DistributedWatch: @unchecked Sendable {
    private let token: NSObjectProtocol

    init(domain: String, _ action: @escaping @Sendable () -> Void) {
        token = DistributedNotificationCenter.default().addObserver(
            forName: RenderingPreference.changed, object: domain, queue: .main) { _ in action() }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(token)
    }
}
