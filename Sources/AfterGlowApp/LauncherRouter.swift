// LauncherRouter.swift: the launcher's app delegate, adapted in AfterGlowApp.
// A document opened from Finder goes to the app that reads it, as an open
// hand-off, and no launcher window opens for it. Services come from
// LauncherServices (LauncherRouter+Services.swift); a hand-off addressed to
// the launcher has no verb yet, so it is left alone.
import AppKit
import SuiteModel
import SuiteShell

@MainActor
final class LauncherDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { await route(url) }
        }
    }

    /// Sends `url` to the app that reads its type; a file no suite type claims is dropped.
    private func route(_ url: URL) async {
        let services = LauncherServices.shared
        guard url.pathExtension != "aghandoff",
              let app = try? services.routing.route(fileName: url.lastPathComponent), app != .launcher,
              let document = SuiteAppDelegate.document(for: url) else { return }
        _ = try? await services.sending.send(HandOff(id: HandOff.newID(), from: .launcher, to: app,
                                                     verb: .open, documents: [document], createdAt: Date()))
    }
}
