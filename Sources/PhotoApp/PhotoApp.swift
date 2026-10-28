// PhotoApp.swift: Photo, the raster editing app. One window per image, laid
// out as SuiteUI's SuiteWindow (the layer list in the sidebar, the canvas with
// rulers, the floating tool palette and the status line, the image header,
// tool options, layer settings and adjustments in the inspector, the commands
// in the window toolbar). The window keeps its title bar and follows the
// system appearance, and View > Hide Sidebar (SidebarCommands) makes room on a
// small screen, and View > Rendering (RenderingCommands over PhotoRendering)
// picks the canvas's backend, live in every window. PhotoWindow holds the state; the menus in PhotoCommands reach
// it through a focused scene value. A window opens 1000 x 700, or at
// `-SuiteWindowSize WxH` when given (SuiteWindow reads it).
//
// PhotoAppDelegate (photo-documents D-10) sends files Finder hands the app
// to an empty window or a new one (PhotoOpenQueue), and on Quit asks each
// dirty window in turn (PhotoUnsavedFlow.quit) through SuiteUI's
// UnsavedGuard; closing a dirty window asks too (`.unsavedChangesGuard`).
//
// File-flow (PF-2): the scene takes part in switching (`.suiteApp`), File
// gets the suite's Open Recent ▸ and Open In ▸ (SuiteFileCommands), and the
// editor takes drops (`.suiteFileDrop`); all three read PhotoShell's one
// documents bridge, which starts watching the suite's recents at launch.
// Finding #4260: the delegate is a SuiteAppDelegate, so a hand-off file
// (Open Recent ▸, Open In from another app) reaches PhotoShell.host, a
// PhotoDocumentHost that opens each image through PhotoOpenQueue.
//
// Editor menus (EM-3): `.suiteEditor` adds Window > Switch To, AI Access…
// and the suite's Help group, and starts PhotoShell.live, a live command
// channel over the front window's image (`afterglow run --live photo`). A
// Dock click with no window open opens one (`.suiteReopenWindow`), and the
// home's New Photo (#3648) starts a new image through PhotoOpenQueue.
import AppKit
import PhotoModel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

/// The process's documents bridge: the suite's recents and routing, on fakes for a `-PhotoFixture` launch.
@MainActor enum PhotoShell {
    static let bridge: SuiteDocumentsBridge = {
        let arguments = ProcessInfo.processInfo.arguments
        let services: SuiteServices = PhotoWindow.launchOptions.fixture == nil
            ? .live(support: SuiteLocations.supportFolder(arguments: arguments, home: NSHomeDirectory()),
                    app: .photo, arguments: arguments)
            : .fake()
        return SuiteDocumentsBridge(app: .photo, services: services)
    }()

    /// The hand-off host: an open hand-off opens each image, and a new one starts an image, in an empty window or a new one.
    static let host = PhotoDocumentHost { requests in
        await MainActor.run {
            for request in requests {
                switch request {
                case .open(let path): PhotoOpenQueue.shared.open(URL(fileURLWithPath: path))
                case .newImage(let width, let height): PhotoOpenQueue.shared.send(.file(.newImage(width: width, height: height)))
                case .handOff, .forget, .clearRecent: continue
                }
            }
        }
    }

    /// Live commands on the front window's image; a client runs only on a grant it already holds.
    static let live = LiveCommandChannel(
        app: SuiteApp.photo.displayName,
        document: { () -> PhotoHeadless? in PhotoWindowEditedView.shown.first?.workspace.map(PhotoHeadless.init(workspace:)) },
        apply: { (result: PhotoHeadless) in PhotoWindowEditedView.shown.first?.send?(.file(.adoptLive(result.workspace))) },
        ask: { await AIAccessCenter.shared.ask($0) })
}

@main
struct PhotoApp: App {
    @NSApplicationDelegateAdaptor private var delegate: PhotoAppDelegate
    /// View > Rendering's checkmark and status line, over the app's live preference.
    @State private var rendering = RenderingMenuModel(preference: PhotoRendering.shared.preference)

    var body: some Scene {
        WindowGroup(id: PhotoOpenQueue.windowID) {
            PhotoWindow().environment(\.photoRendering, PhotoRendering.shared)
                .suiteReopenWindow(id: PhotoOpenQueue.windowID)
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            SidebarCommands()
            PhotoCommands()
            RenderingCommands(model: rendering)
        }
        .suiteEditor(.photo, host: PhotoShell.host, live: PhotoShell.live)
    }
}

/// Finder opens, suite hand-offs, the suite's recents and Quit's unsaved-changes prompts.
@MainActor final class PhotoAppDelegate: SuiteAppDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await PhotoShell.bridge.watch() }
    }

    override func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.pathExtension == "aghandoff" {
                Task { await self.handle(url) }
            } else {
                PhotoOpenQueue.shared.open(url)
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let windows = PhotoWindowEditedView.shown
        guard windows.contains(where: { $0.isDirty }) else { return .terminateNow }
        Task { @MainActor in sender.reply(toApplicationShouldTerminate: await PhotoUnsavedFlow.quit(windows)) }
        return .terminateLater
    }
}

/// Files and new images waiting for a window: an empty window takes one at
/// once, else a new window is asked for and takes the oldest when it appears.
@MainActor final class PhotoOpenQueue {
    static let shared = PhotoOpenQueue()
    static let windowID = "photo"
    private var pending: [PhotoIntent] = []
    /// The first window's `openWindow` (nil until a window appears).
    private var openWindow: OpenWindowAction?

    func open(_ url: URL) { send(.openFile(url)) }

    /// `intent` (an open or a new image) to an empty window, or to a new one.
    func send(_ intent: PhotoIntent) {
        if let empty = PhotoWindowEditedView.shown.first(where: { $0.isEmpty }) {
            empty.send?(intent)
            return
        }
        pending.append(intent)
        openWindow?.callAsFunction(id: Self.windowID)
    }

    /// A window appeared: the oldest intent waiting for it, or nil. The first
    /// window also asks for one per intent that came before it could.
    func windowAppeared(_ openWindow: OpenWindowAction) -> PhotoIntent? {
        let first = self.openWindow == nil
        self.openWindow = openWindow
        let intent = pending.isEmpty ? nil : pending.removeFirst()
        if first { for _ in pending { openWindow(id: Self.windowID) } }
        return intent
    }
}

/// One window's side of Quit's unsaved-changes walk; tests pass fakes.
@MainActor protocol PhotoUnsavedWindow: AnyObject {
    var isDirty: Bool { get }
    /// The window the sheet goes on; nil asks modally.
    var window: NSWindow? { get }
    /// What SuiteUI's guard asks with.
    var unsavedHooks: UnsavedHooks { get }
    /// Quit: the last autosave before asking.
    func prepareToQuit() async
    /// Don't Save: drops the autosave.
    func discardChanges()
}

/// What Quit does with each window's answer.
@MainActor enum PhotoUnsavedFlow {
    /// Quit: asks each dirty window in turn, autosaved first; true to quit.
    /// Don't Save drops autosaves once all answered, so a Cancel keeps them.
    static func quit(_ windows: [any PhotoUnsavedWindow]) async -> Bool {
        var dropped: [any PhotoUnsavedWindow] = []
        for window in windows where window.isDirty {
            await window.prepareToQuit()
            guard await UnsavedGuard.proceed(window.unsavedHooks, in: window.window) else { return false }
            if window.isDirty { dropped.append(window) }
        }
        for window in dropped { window.discardChanges() }
        return true
    }
}
