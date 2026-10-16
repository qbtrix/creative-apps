// FakeSwitching.swift: the in-memory AppSwitching (UC-1). A missing app is
// refused with `appMissing`; `terminate` is the test hook for a quit or crash.
// With `unavailable:` set, `switchTo` throws `.notAvailable(that sentence)`.

public actor FakeSwitching: AppSwitching {
    public private(set) var states: [SuiteApp: AppRunState]
    public private(set) var ticks: Double = 0
    var feed = ChangeFeed()
    let unavailable: String?
    public init(running: [SuiteApp] = [], missing: Set<SuiteApp> = [], unavailable: String? = nil) {
        var s: [SuiteApp: AppRunState] = [:]
        for app in SuiteApp.allCases { s[app] = missing.contains(app) ? .missing : running.contains(app) ? .running(windows: 1) : .notRunning }
        s[.launcher] = .running(windows: 1)
        states = s
        self.unavailable = unavailable
    }
    public func runState(of app: SuiteApp) -> AppRunState { states[app] ?? .notRunning }
    public func changes() -> AsyncStream<Int> { feed.stream() }
    public func switchTo(_ app: SuiteApp, reason: SwitchReason) throws(SuiteError) -> SwitchReceipt {
        if let unavailable { throw .notAvailable(unavailable) }
        let before = states[app] ?? .notRunning
        if before == .missing { throw .appMissing(app) }
        ticks += 1
        if case .running = before { return SwitchReceipt(app: app, wasRunning: true, requestedAt: ticks) }
        states[app] = .running(windows: 1)
        feed.send(Int(ticks))
        return SwitchReceipt(app: app, wasRunning: false, requestedAt: ticks)
    }
    /// Test hook: the app quit or crashed.
    public func terminate(_ app: SuiteApp) { states[app] = .notRunning; ticks += 1; feed.send(Int(ticks)) }
}
