// HandOffTransport.swift: delivers a hand-off file to the app it is for (UC-5;
// blueprint 2.6, hand-off transport). Launch Services opens the file with that
// app: a running app comes forward, and one that isn't running launches with
// the suite's arguments.
import AppKit
import SuiteModel

public enum HandOffTransport {
    public static func deliver(_ path: String, to app: SuiteApp) async throws(SuiteError) -> SwitchReceipt {
        let requestedAt = ProcessInfo.processInfo.systemUptime
        let wasRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = LaunchArguments.forward(ProcessInfo.processInfo.arguments, to: app)
        configuration.activates = true
        let helper = URL(fileURLWithPath: launcherBundlePath() + "/" + app.bundlePath)
        do {
            _ = try await NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: helper, configuration: configuration)
        } catch {
            throw .notAvailable("\(app.displayName) didn't open the message. Try again.")
        }
        return SwitchReceipt(app: app, wasRunning: wasRunning, requestedAt: requestedAt)
    }
}
