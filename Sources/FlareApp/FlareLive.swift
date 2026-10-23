// FlareLive.swift (editor-menus EM-5): Flare's end of the suite's live command channel. `FlareLive.channel`
// runs an `afterglow` command on the frontmost window's workspace (as FlareHeadless) and hands the result back to
// that window, which takes it through `FlareWorkspace.takeLive`. A window registers when it appears and each
// time it becomes the active one (FlareLiveRegistration), and lets go when it closes. With no window the
// channel answers "no document open". A client without a grant is asked through AIAccessCenter.ask, the
// approval sheet on the front window.
import FlareModel
import SuiteModel
import SuiteShell
import SwiftUI

/// The window the live channel reads and writes, and the channel itself.
@MainActor enum FlareLive {
    private static var owner: UUID?
    private static var read: @MainActor () -> FlareWorkspace? = { nil }
    private static var write: @MainActor (FlareHeadless) -> Void = { _ in }

    static let channel = LiveCommandChannel(
        app: SuiteApp.flare.displayName,
        document: { read().map(FlareHeadless.init(workspace:)) },
        apply: { write($0) },
        ask: { await AIAccessCenter.shared.ask($0) })

    /// Makes the window `id` the one live commands reach.
    static func register(_ id: UUID, read: @escaping @MainActor () -> FlareWorkspace?,
                         write: @escaping @MainActor (FlareHeadless) -> Void) {
        (owner, Self.read, Self.write) = (id, read, write)
    }

    /// The window `id` closed: live commands reach no window until another registers.
    static func release(_ id: UUID) {
        guard owner == id else { return }
        (owner, read, write) = (nil, { nil }, { _ in })
    }
}

/// Registers its window with FlareLive on appear and whenever it becomes active; releases it on close.
struct FlareLiveRegistration: ViewModifier {
    let read: @MainActor () -> FlareWorkspace?
    let write: @MainActor (FlareHeadless) -> Void
    @State private var id = UUID()
    @Environment(\.appearsActive) private var appearsActive

    func body(content: Content) -> some View {
        content
            .onChange(of: appearsActive, initial: true) { _, active in
                if active { FlareLive.register(id, read: read, write: write) }
            }
            .onDisappear { FlareLive.release(id) }
    }
}
