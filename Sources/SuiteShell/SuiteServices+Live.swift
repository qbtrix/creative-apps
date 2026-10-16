// SuiteServices+Live.swift: the services a real suite process uses
// (suite-contracts packet, correction 8). `live` builds one SlotContext and
// asks each member's slot in Live/ for its conformance; a slot that isn't
// live yet holds its fake, which throws "Not connected yet (<feature>)."
// (pure members hold the reference fake), and `pending` lists every such
// member so views disable its controls with that reason. The seven members
// below without a slot file yet are inline fakes until SC-5c. `animations`
// and `updates` stay fakes; a process swaps them with `with(...)`.
import SuiteModel

/// What every slot may need to build its member.
public struct SlotContext: Sendable {
    public let store: FileStore
    public let support: String
    public let app: SuiteApp
    public let arguments: [String]

    public init(store: FileStore, support: String, app: SuiteApp, arguments: [String]) {
        self.store = store; self.support = support; self.app = app; self.arguments = arguments
    }
}

extension SuiteServices {
    /// The live services for `app`, sharing the support folder `support`.
    public static func live(support: String, app: SuiteApp, arguments: [String]) -> SuiteServices {
        let c = SlotContext(store: FileStore(folder: support), support: support, app: app, arguments: arguments)
        let handOffs = handOffSlot(c)
        var s = SuiteServices(
            switching: switchingSlot(c), recents: recentsSlot(c), creating: creatingSlot(c), routing: routingSlot(c),
            sending: handOffs, receiving: handOffs,
            roundTrips: FakeRoundTrips(unavailable: notConnected("roundTrips")), pasteboard: FakePasteboard(),
            assets: FakeAssets(unavailable: notConnected("assets")), linking: FakeLinking(),
            animations: FakeAnimationSource(), preferences: FakePreferences(unavailable: notConnected("preferences")),
            settings: FakeSettingsRoute(unavailable: notConnected("settings")), onboarding: FakeOnboarding(),
            updates: FakeUpdates(), thumbnails: thumbnailsSlot(c), home: homeSlot(c), isPreview: false)
        s.pending = pendingReasons(liveness: slotLiveness)
        return s
    }

    /// Each slotted member to whether its slot is live; one flag per slot file.
    static let slotLiveness: [String: Bool] = [
        "switching": switchingIsLive, "recents": recentsIsLive, "creating": creatingIsLive,
        "routing": routingIsLive, "sending": handOffIsLive, "receiving": handOffIsLive,
        "thumbnails": thumbnailsIsLive, "home": homeIsLive,
        "roundTrips": false, "pasteboard": false, "assets": false, "linking": false,
        "preferences": false, "settings": false, "onboarding": false,
    ]

    /// Every slotted member whose slot isn't live, with its not-connected reason.
    static func pendingReasons(liveness: [String: Bool]) -> [String: String] {
        slotFeatures.filter { liveness[$0.key] != true }.mapValues(SuiteIdentity.notConnected)
    }
}
