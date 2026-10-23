// HaloLive.swift (editor-menus EM-6): Halo's end of the suite's live command channel. `HaloLive.channel` runs
// an `afterglow` command on the active window's project (as HaloHeadless) and hands it back; the window lands it
// with `HaloProject.landLive`, the command's undo step included. Each window takes the channel when it appears
// or becomes active (HaloLiveTaking) and gives it up when it closes, so with none the call answers "no
// document open". `ask` refuses: SuiteShell has no async approval sheet yet, so only a client granted Always
// Allow runs, and any other is refused (Revoke in Window > AI Access… clears it).
import HaloModel
import SuiteModel
import SuiteShell
import SwiftUI

/// Which window live commands reach, and the channel that runs them.
@MainActor enum HaloLive {
    private static var window: UUID?
    private static var project: @MainActor () -> HaloProject? = { nil }
    private static var land: @MainActor (HaloProject) -> Void = { _ in }

    static let channel = LiveCommandChannel(
        app: SuiteApp.halo.displayName,
        document: { project().map(HaloHeadless.init(workspace:)) },
        apply: { land($0.workspace) },
        ask: { _ in .deny })

    /// Live commands now reach the window `id`.
    static func take(_ id: UUID, project: @escaping @MainActor () -> HaloProject?, land: @escaping @MainActor (HaloProject) -> Void) {
        (window, Self.project, Self.land) = (id, project, land)
    }

    /// The window `id` is gone; until another takes over, no window is.
    static func giveUp(_ id: UUID) {
        guard window == id else { return }
        window = nil
        project = { nil }
        land = { _ in }
    }
}

/// Hands its window to HaloLive when it appears or becomes active, and takes it back when it closes.
struct HaloLiveTaking: ViewModifier {
    let project: @MainActor () -> HaloProject?
    let land: @MainActor (HaloProject) -> Void
    @State private var id = UUID()
    @Environment(\.appearsActive) private var appearsActive

    func body(content: Content) -> some View {
        content
            .onChange(of: appearsActive, initial: true) { _, active in
                guard active else { return }
                HaloLive.take(id, project: project, land: land)
            }
            .onDisappear { HaloLive.giveUp(id) }
    }
}
