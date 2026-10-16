// PhotoApp.swift: Photo, the raster editing app. One window per image, laid
// out as SuiteUI's SuiteWindow (the layer list in the sidebar, the canvas with
// rulers, the floating tool palette and the status line, the image header,
// tool options, layer settings and adjustments in the inspector, the commands
// in the window toolbar). The window keeps its title bar and follows the
// system appearance, and View > Hide Sidebar (SidebarCommands) makes room on a
// small screen. PhotoWindow holds the state; the menus in PhotoCommands reach
// it through a focused scene value. A window opens `-PhotoWindowWidth` points
// wide when given (880...4096), else 1280.
//
// PhotoAppDelegate (photo-documents D-10) sends files Finder hands the app
// to an empty window or a new one (PhotoOpenQueue), and on Quit asks each
// dirty window in turn (PhotoUnsavedFlow.quit); closing a dirty window asks
// too (PhotoUnsavedFlow.close, from PhotoWindowEditedView's close guard).
import AppKit
import PhotoModel
import SwiftUI

@main
struct PhotoApp: App {
    @NSApplicationDelegateAdaptor private var delegate: PhotoAppDelegate

    var body: some Scene {
        WindowGroup(id: PhotoOpenQueue.windowID) { PhotoWindow() }
            .defaultSize(width: CGFloat(PhotoWindow.launchOptions.windowWidth ?? 1280), height: 820)
            .commands {
                SidebarCommands()
                PhotoCommands()
            }
    }
}

/// Finder opens and Quit's unsaved-changes prompts.
@MainActor final class PhotoAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { PhotoOpenQueue.shared.open(url) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let windows = PhotoWindowEditedView.shown
        guard windows.contains(where: { $0.isDirty }) else { return .terminateNow }
        Task { @MainActor in sender.reply(toApplicationShouldTerminate: await PhotoUnsavedFlow.quit(windows)) }
        return .terminateLater
    }
}

/// Files waiting for a window: an empty window opens one at once, else a
/// new window is asked for and takes the oldest when it appears.
@MainActor final class PhotoOpenQueue {
    static let shared = PhotoOpenQueue()
    static let windowID = "photo"
    private var pending: [URL] = []
    /// The first window's `openWindow` (nil until a window appears).
    private var openWindow: OpenWindowAction?

    func open(_ url: URL) {
        if let empty = PhotoWindowEditedView.shown.first(where: { $0.isEmpty }) {
            empty.send?(.openFile(url))
            return
        }
        pending.append(url)
        openWindow?.callAsFunction(id: Self.windowID)
    }

    /// A window appeared: the oldest file waiting for it, or nil. The first
    /// window also asks for one per file that came before it could.
    func windowAppeared(_ openWindow: OpenWindowAction) -> URL? {
        let first = self.openWindow == nil
        self.openWindow = openWindow
        let url = pending.isEmpty ? nil : pending.removeFirst()
        if first { for _ in pending { openWindow(id: Self.windowID) } }
        return url
    }
}

/// One window's side of the unsaved-changes prompt; tests pass fakes.
@MainActor protocol PhotoUnsavedWindow: AnyObject {
    var isDirty: Bool { get }
    /// Quit: the last autosave before asking.
    func prepareToQuit() async
    func ask() async -> PhotoUnsavedPrompt.Answer
    /// Save; true once it landed.
    func save() async -> Bool
    /// Don't Save: drops the autosave.
    func discardChanges()
}

/// What close and Quit do with each window's answer.
@MainActor enum PhotoUnsavedFlow {
    /// Whether closing asks first: only a dirty window does.
    static func asksOnClose(_ window: any PhotoUnsavedWindow) -> Bool { window.isDirty }

    /// Close: true when the window may close (clean, saved, or Don't Save).
    static func close(_ window: any PhotoUnsavedWindow) async -> Bool {
        guard asksOnClose(window) else { return true }
        switch await window.ask() {
        case .save: return await window.save()
        case .dontSave:
            window.discardChanges()
            return true
        case .cancel: return false
        }
    }

    /// Quit: asks each dirty window in turn, autosaved first; true to quit.
    /// Don't Save drops autosaves once all answered, so a Cancel keeps them.
    static func quit(_ windows: [any PhotoUnsavedWindow]) async -> Bool {
        var dropped: [any PhotoUnsavedWindow] = []
        for window in windows where window.isDirty {
            await window.prepareToQuit()
            switch await window.ask() {
            case .save: guard await window.save() else { return false }
            case .dontSave: dropped.append(window)
            case .cancel: return false
            }
        }
        for window in dropped { window.discardChanges() }
        return true
    }
}
