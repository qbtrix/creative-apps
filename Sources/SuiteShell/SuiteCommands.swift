// SuiteCommands.swift: the menu commands every suite process adds. Window >
// Switch To with Home (Control-Command-0) and the five apps (Control-Command-1
// to 5). The items come from SwitchMenu, so each one is enabled exactly when
// the switcher's is, and a disabled one says why; a click switches through
// AppLauncher. The initializer's signature is the one switching keeps.
import Foundation
import SuiteModel
import SwiftUI

/// Window > Switch To, the shared menu every app and the launcher add.
public struct SuiteCommands: Commands {
    private let app: SuiteApp
    private let bundle: String
    private let hidden: Set<SuiteApp>
    private let launcher: AppLauncher

    public init(app: SuiteApp = .launcher) {
        let arguments = ProcessInfo.processInfo.arguments
        let bundle = launcherBundlePath()
        self.app = app
        self.bundle = bundle
        self.hidden = AppLauncher.hiddenApps(in: arguments)
        self.launcher = AppLauncher(bundle: bundle, arguments: arguments)
    }

    public var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Menu("Switch To") {
                ForEach(SwitchMenu.items(current: app, states: runStates()), id: \.app) { item in
                    Button(item.title) { switchTo(item.app) }
                        .keyboardShortcut(KeyEquivalent(Character(String(item.digit))), modifiers: [.control, .command])
                        .disabled(!item.enabled).help(item.reason ?? "")
                }
            }
        }
    }

    /// Brings `app` forward, or opens it, as a Switch To click asks.
    private func switchTo(_ app: SuiteApp) {
        let launcher = self.launcher
        Task { _ = try? await launcher.switchTo(app, reason: .menu) }
    }

    /// Each app's run state as the menu reads it now.
    private func runStates() -> [SuiteApp: AppRunState] {
        Dictionary(uniqueKeysWithValues: SuiteApp.allCases.map {
            ($0, AppLauncher.state(of: $0, bundle: bundle, hidden: hidden))
        })
    }
}
