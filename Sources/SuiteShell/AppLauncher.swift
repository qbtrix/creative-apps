// AppLauncher.swift: the live `AppSwitching` (UC-1; blueprint 2.3, shell-apps).
// An app running with windows comes forward; one with no window, or not
// running, is opened from the AfterGlow bundle with the suite's arguments; a
// missing app is refused. `-SuiteHideApp <app>` makes an app read as missing,
// for the tests. The run state's window count is 1 for a running app: the
// probe that counts real windows is not wired yet.
import AppKit
import SuiteModel

public actor AppLauncher: AppSwitching {
    private let bundle: String
    private let arguments: [String]
    private let hidden: Set<SuiteApp>
    private var continuations: [AsyncStream<Int>.Continuation] = []
    private var counter = 0

    /// `bundle` is the AfterGlow.app that holds the helper apps; `arguments` are this process's, from which a launched app takes its own flags.
    public init(bundle: String, arguments: [String]) {
        self.bundle = bundle
        self.arguments = arguments
        self.hidden = Self.hiddenApps(in: arguments)
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                Task { await self?.runStateChanged() }
            }
        }
    }

    public func runState(of app: SuiteApp) -> AppRunState {
        Self.state(of: app, bundle: bundle, hidden: hidden)
    }

    /// The run state of `app` in the AfterGlow bundle at `bundle`. Static so the
    /// Switch To menu can read it while it builds, without awaiting the actor.
    static func state(of app: SuiteApp, bundle: String, hidden: Set<SuiteApp>) -> AppRunState {
        guard !hidden.contains(app), FileManager.default.fileExists(atPath: path(of: app, bundle: bundle)) else { return .missing }
        return NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty ? .notRunning : .running(windows: 1)
    }

    public func changes() -> AsyncStream<Int> {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        continuations.append(continuation)
        return stream
    }

    public func switchTo(_ app: SuiteApp, reason: SwitchReason) async throws(SuiteError) -> SwitchReceipt {
        let state = runState(of: app)
        let wasRunning: Bool
        if case .running = state { wasRunning = true } else { wasRunning = false }
        let requestedAt = ProcessInfo.processInfo.systemUptime
        switch SwitchPlanner.action(for: app, state: state) {
        case .refuse(let error):
            throw error
        case .activate:
            _ = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).first?.activate(options: [.activateAllWindows])
        case .open:
            try await open(app)
        }
        return SwitchReceipt(app: app, wasRunning: wasRunning, requestedAt: requestedAt)
    }

    private func open(_ app: SuiteApp) async throws(SuiteError) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = LaunchArguments.forward(arguments, to: app)
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: Self.path(of: app, bundle: bundle)), configuration: configuration)
        } catch {
            throw .notAvailable("\(app.displayName) didn't open. Try again.")
        }
    }

    private func runStateChanged() {
        counter += 1
        for continuation in continuations { continuation.yield(counter) }
    }

    static func path(of app: SuiteApp, bundle: String) -> String {
        app == .launcher ? bundle : bundle + "/" + app.bundlePath
    }

    static func hiddenApps(in arguments: [String]) -> Set<SuiteApp> {
        var hidden: Set<SuiteApp> = []
        for index in arguments.indices where arguments[index] == "-SuiteHideApp" && index + 1 < arguments.count {
            if let app = SuiteApp(rawValue: arguments[index + 1]) { hidden.insert(app) }
        }
        return hidden
    }
}
