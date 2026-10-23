// SuiteEditorScene.swift (editor-menus EM-1): `.suiteEditor(_:host:live:)`,
// the one scene modifier every suite editor adds (blueprint 2.6, 6). It is
// `.suiteApp(app, host:, live:)` plus the suite's menus: SuiteCommands'
// Window > Switch To, which carries AIAccessCommands' Window > AI Access…
// itself (so it is not added twice), and SuiteHelpCommands' Help group, which
// replaces the system's app help. The Dock reopen rule lives in
// SuiteAppDelegate; `.suiteReopenWindow(id:)` lets a window's root hand the
// delegate the action that opens that scene's window again.
import SuiteModel
import SwiftUI

extension Scene {
    /// `.suiteApp(app, host:, live:)` plus Switch To, AI Access and the Help group (replacing `.help`).
    @MainActor
    public func suiteEditor(_ app: SuiteApp, host: any SuiteDocumentHost, live: LiveCommandChannel?) -> some Scene {
        suiteApp(app, host: host, live: live)
            .commands {
                SuiteCommands(app: app)
                SuiteHelpCommands(app: app)
            }
    }
}

extension View {
    /// Registers `openWindow(id: id)` as the suite delegate's `openWindow`, so
    /// a Dock click with no window open reopens the scene `id` names (a
    /// `Window`, which the system doesn't recreate itself, or a `WindowGroup`).
    @MainActor
    public func suiteReopenWindow(id: String) -> some View {
        modifier(SuiteReopenRegistration(id: id))
    }
}

/// Hands the window's `openWindow` action to SuiteAppDelegate when the window appears.
struct SuiteReopenRegistration: ViewModifier {
    let id: String
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            let open = openWindow
            let id = id
            SuiteAppRegistry.delegate?.openWindow = { open(id: id) }
        }
    }
}
