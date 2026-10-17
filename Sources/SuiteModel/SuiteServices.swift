// SuiteServices.swift: one member per suite contract (blueprint
// suite/contracts/Services.swift). `.fake` is every fake; SuiteShell builds
// `.live` from one slot file per member. `slotFeatures` and `pending` give each
// not-yet-live member its reason (packet correction 6). Linux-safe.

/// Every suite service one process uses, one member per contract.
public struct SuiteServices: Sendable {
    public var switching: any AppSwitching
    public var recents: any RecentWork
    public var creating: any DocumentCreating
    public var routing: any DocumentRouting
    public var sending: any HandOffSending
    public var receiving: any HandOffReceiving
    public var roundTrips: any RoundTripEditing
    public var pasteboard: any PasteboardCoding
    public var assets: any AssetLibrary
    public var linking: any AssetLinking
    public var animations: any AnimationSourceReading
    public var preferences: any PreferencesStoring
    public var settings: any SettingsRouting
    public var onboarding: any OnboardingFlowing
    public var updates: any UpdateChecking
    public var thumbnails: any ThumbnailPublishing
    public var home: any HomeBuilding
    /// True only for `.fake(...)` (snapshots, Model tests); `.live` sets false even while
    /// a slot still holds a not-connected fake, whose controls say so themselves.
    public var isPreview: Bool
    /// Member name to "<What> isn't available yet." for every member not live
    /// yet; a view disables a control whose member is here and shows the reason.
    public var pending: [String: String]

    public init(switching: any AppSwitching, recents: any RecentWork, creating: any DocumentCreating,
                routing: any DocumentRouting, sending: any HandOffSending, receiving: any HandOffReceiving,
                roundTrips: any RoundTripEditing, pasteboard: any PasteboardCoding, assets: any AssetLibrary,
                linking: any AssetLinking, animations: any AnimationSourceReading, preferences: any PreferencesStoring,
                settings: any SettingsRouting, onboarding: any OnboardingFlowing, updates: any UpdateChecking,
                thumbnails: any ThumbnailPublishing, home: any HomeBuilding, isPreview: Bool,
                pending: [String: String] = [:]) {
        self.switching = switching; self.recents = recents; self.creating = creating; self.routing = routing
        self.sending = sending; self.receiving = receiving; self.roundTrips = roundTrips; self.pasteboard = pasteboard
        self.assets = assets; self.linking = linking; self.animations = animations; self.preferences = preferences
        self.settings = settings; self.onboarding = onboarding; self.updates = updates; self.thumbnails = thumbnails
        self.home = home; self.isPreview = isPreview; self.pending = pending
    }

    /// Members a process supplies itself: Halo's animation reader (it links FlareCore)
    /// and the launcher's updater (it owns the bundle). SuiteShell can see neither.
    public func with(animations: (any AnimationSourceReading)? = nil, updates: (any UpdateChecking)? = nil) -> SuiteServices {
        var s = self
        if let animations { s.animations = animations }
        if let updates { s.updates = updates }
        return s
    }

    /// Every member a fake, seeded from a fixture's recents and assets.
    public static func fake(recents: RecentsList = RecentsList(), assets: AssetIndex = AssetIndex(),
                            running: [SuiteApp] = [], missing: Set<SuiteApp> = []) -> SuiteServices {
        let switching = FakeSwitching(running: running, missing: missing)
        let handOffs = FakeHandOffs(switching: switching)
        return SuiteServices(switching: switching, recents: FakeRecents(recents), creating: FakeCreating(),
                             routing: FakeRouting(), sending: handOffs, receiving: handOffs,
                             roundTrips: FakeRoundTrips(), pasteboard: FakePasteboard(), assets: FakeAssets(assets),
                             linking: FakeLinking(), animations: FakeAnimationSource(), preferences: FakePreferences(),
                             settings: FakeSettingsRoute(), onboarding: FakeOnboarding(), updates: FakeUpdates(),
                             thumbnails: FakeThumbnails(), home: FakeHome(), isPreview: true)
    }

    /// Each slotted member (all but `animations` and `updates`, which a process
    /// supplies through `with`) to the feature that connects it
    /// (docs/blueprints/suite.md 8.2, the packet's ownership after this feature).
    public static let slotFeatures: [String: String] = [
        "switching": "switching", "sending": "switching", "receiving": "switching",
        "recents": "recents-open-in", "routing": "recents-open-in", "thumbnails": "recents-open-in",
        "creating": "home", "home": "home",
        "preferences": "settings", "settings": "settings",
        "pasteboard": "clipboard-drag", "roundTrips": "photo-round-trip", "assets": "shared-assets",
        "onboarding": "onboarding", "linking": "linked-assets",
    ]

    /// The not-connected reason of a slotted member: its `slotFeatures` slug in
    /// plain words (`SuiteIdentity.featurePhrases`), never the slug itself.
    public static func notConnected(_ member: String) -> String? {
        slotFeatures[member].map(SuiteIdentity.notConnected)
    }
}
