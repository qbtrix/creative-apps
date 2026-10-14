// Services.swift: SuiteServices (SuiteModel, planned
// `Sources/SuiteModel/SuiteServices.swift`). One member per contract.
// `.fake` is every fake; SuiteShell builds `.live` from one slot file per
// member (`Sources/SuiteShell/Live/<Member>Slot.swift`), each returning the
// fake with an `unavailable` reason until its feature swaps it, so features
// in one wave never edit the same file.

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
    public var size: any SizeBudgetChecking
    /// True while any member is a fake; drives a "Preview data" pill in the home.
    public var isPreview: Bool

    public init(switching: any AppSwitching, recents: any RecentWork, creating: any DocumentCreating,
                routing: any DocumentRouting, sending: any HandOffSending, receiving: any HandOffReceiving,
                roundTrips: any RoundTripEditing, pasteboard: any PasteboardCoding, assets: any AssetLibrary,
                linking: any AssetLinking, animations: any AnimationSourceReading, preferences: any PreferencesStoring,
                settings: any SettingsRouting, onboarding: any OnboardingFlowing, updates: any UpdateChecking,
                thumbnails: any ThumbnailPublishing, home: any HomeBuilding, size: any SizeBudgetChecking, isPreview: Bool) {
        self.switching = switching; self.recents = recents; self.creating = creating; self.routing = routing
        self.sending = sending; self.receiving = receiving; self.roundTrips = roundTrips; self.pasteboard = pasteboard
        self.assets = assets; self.linking = linking; self.animations = animations; self.preferences = preferences
        self.settings = settings; self.onboarding = onboarding; self.updates = updates; self.thumbnails = thumbnails
        self.home = home; self.size = size; self.isPreview = isPreview
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
                             thumbnails: FakeThumbnails(), home: FakeHome(), size: FakeSizeBudget(), isPreview: true)
    }
}
