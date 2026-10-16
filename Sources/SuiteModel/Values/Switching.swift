// Switching.swift: whether an app is running, why a switch was asked for,
// and the receipt a switch hands back. Foundation free, Linux-safe,
// Sendable.

/// Where one app stands, as the switcher sees it.
public enum AppRunState: Equatable, Sendable {
    case notRunning, launching, running(windows: Int), missing
}

/// What asked for a switch.
public enum SwitchReason: String, Codable, Sendable { case shortcut, menu, home, handOff }

/// What a switch request hands back, so its latency can be measured.
public struct SwitchReceipt: Equatable, Sendable {
    public var app: SuiteApp
    public var wasRunning: Bool
    public var requestedAt: Double      // system uptime seconds (ProcessInfo.systemUptime, NSEvent.timestamp's clock)
    public init(app: SuiteApp, wasRunning: Bool, requestedAt: Double) {
        self.app = app; self.wasRunning = wasRunning; self.requestedAt = requestedAt
    }
}
